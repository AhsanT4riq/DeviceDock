#!/bin/bash
# macOS ships Bash 3.2. Keep this script compatible with it.
set -euo pipefail

ROOT=$(cd "$(dirname "$0")/.." && pwd)
cd "$ROOT"
PROJECT=DeviceDock.xcodeproj/project.pbxproj
TEAM=P24JM6N5FP
NOTARY_PROFILE=${NOTARY_PROFILE:-DeviceDock-notary}
TEMP_DIR=
trap 'if [[ -n "$TEMP_DIR" ]]; then rm -rf "$TEMP_DIR"; fi' EXIT

die() { printf 'Error: %s\n' "$*" >&2; exit 1; }
usage() {
    cat <<'HELP'
Usage: scripts/release.sh bump <X.Y.Z>
       scripts/release.sh build [--skip-notarize] [--allow-dirty]
       scripts/release.sh --help

bump   Update both target configurations and increment the build number.
       The version must increase. This command never commits changes.
build  Archive, export with Developer ID, notarize, staple, zip, and verify.
       Output: build/release/<version>/DeviceDock.zip
       --skip-notarize  Test signing/packaging without contacting notarytool.
                       The resulting app is NOT ready for distribution.
       --allow-dirty   Testing only: bypass clean-tree, main branch, origin
                       sync/fetch, and local/remote tag checks. All signing,
                       notarization (unless skipped), and artifact checks remain.

NOTARY_PROFILE defaults to DeviceDock-notary. The owner must create this
keychain profile separately; this script never creates or handles credentials.
Normal build requires a clean main not behind or diverged from origin/main
and an unused version tag. Unpushed local commits are allowed.
Existing archive/export/zip paths are never overwritten; move the version's
output directory aside before retrying. This script never commits or publishes.
HELP
}

# Fail rather than silently choosing one of two inconsistent configurations.
setting() {
    local values count unique
    values=$(sed -nE "s/^[[:space:]]*$1 = ([^;]+);/\1/p" "$PROJECT")
    count=$(printf '%s\n' "$values" | wc -l | tr -d ' ')
    unique=$(printf '%s\n' "$values" | sort -u)
    [[ "$count" == 2 && "$unique" != *$'\n'* && -n "$unique" ]] ||
        die "$1 must have two matching target values in $PROJECT. Reconcile Debug and Release."
    printf '%s\n' "$unique"
}

bump() {
    [[ $# == 1 ]] || die 'Usage: scripts/release.sh bump <X.Y.Z>'
    # Perl is bundled with macOS. Validate everything before writing the file.
    perl - "$PROJECT" "$1" <<'PERL'
use strict;
use warnings;
my ($path, $next) = @ARGV;
my $semver = qr/(?:0|[1-9][0-9]*)\.(?:0|[1-9][0-9]*)\.(?:0|[1-9][0-9]*)/;
die "Error: version must be X.Y.Z (numbers without leading zeroes).\n" unless $next =~ /^$semver$/;
open my $in, '<', $path or die "$path: $!\n";
local $/;
my $text = <$in>;
close $in;
my @versions = $text =~ /^\s*MARKETING_VERSION = ([^;]+);/mg;
my @builds = $text =~ /^\s*CURRENT_PROJECT_VERSION = ([^;]+);/mg;
die "Error: expected two matching versions and integer build numbers.\n"
    unless @versions == 2 && @builds == 2 && $versions[0] eq $versions[1]
    && $versions[0] =~ /^$semver$/ && $builds[0] eq $builds[1] && $builds[0] =~ /^[0-9]+$/;
my @old = split /\./, $versions[0];
my @new = split /\./, $next;
my $comparison = 0;
for my $i (0..2) { $comparison = $new[$i] <=> $old[$i]; last if $comparison; }
die "Error: $next must be greater than $versions[0].\n" unless $comparison > 0;
my $build = $builds[0] + 1;
$text =~ s/^(\s*MARKETING_VERSION = )[^;]+;/${1}$next;/mg;
$text =~ s/^(\s*CURRENT_PROJECT_VERSION = )[^;]+;/${1}$build;/mg;
open my $out, '>', $path or die "$path: $!\n";
print {$out} $text or die "Write $path: $!\n";
close $out or die "Close $path: $!\n";
print "Version: $versions[0] -> $next\nBuild: $builds[0] -> $build\n";
PERL
}

# Verify the exported app and the copy extracted from the final distribution zip.
verify_app() {
    local app=$1 details assessment
    [[ $(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$app/Contents/Info.plist") == "$VERSION" ]] || die "Version mismatch in $app"
    [[ $(/usr/libexec/PlistBuddy -c 'Print :CFBundleVersion' "$app/Contents/Info.plist") == "$BUILD" ]] || die "Build mismatch in $app"
    codesign --verify --deep --strict "$app"
    details=$(codesign -dv --verbose=4 "$app" 2>&1)
    printf '%s\n' "$details" | grep -Eq '^Authority=Developer ID Application: .* \(P24JM6N5FP\)$' || die "Expected Developer ID Application authority in $app"
    printf '%s\n' "$details" | grep -qx "TeamIdentifier=$TEAM" || die "Wrong signing team in $app"
    printf '%s\n' "$details" | grep '^Authority=\|^TeamIdentifier='
    if [[ "$SKIP_NOTARIZE" == false ]]; then
        xcrun stapler validate "$app"
        if ! assessment=$(spctl -a -t exec -vv "$app" 2>&1); then
            printf '%s\n' "$assessment" >&2
            die "Gatekeeper rejected $app. Inspect notarization and signing."
        fi
        printf '%s\n' "$assessment"
        printf '%s\n' "$assessment" | grep -q ': accepted$' || die 'Gatekeeper did not report accepted.'
        printf '%s\n' "$assessment" | grep -qx 'source=Notarized Developer ID' || die 'Gatekeeper did not report Notarized Developer ID.'
    fi
}

build_release() {
    SKIP_NOTARIZE=false
    local allow_dirty=false arg identities remote_tag app submission_status submission_id submit_exit
    for arg in "$@"; do
        case "$arg" in
            --skip-notarize) SKIP_NOTARIZE=true ;;
            --allow-dirty) allow_dirty=true ;;
            *) die "Unknown build option: $arg (see --help)" ;;
        esac
    done
    VERSION=$(setting MARKETING_VERSION)
    BUILD=$(setting CURRENT_PROJECT_VERSION)
    [[ "$VERSION" =~ ^(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)$ ]] || die 'Project version must be X.Y.Z.'
    [[ "$BUILD" =~ ^[0-9]+$ ]] || die 'Project build must be an integer.'

    if [[ "$allow_dirty" == false ]]; then
        [[ -z $(git status --porcelain --untracked-files=all) ]] || die 'Working tree is dirty. Commit or stash changes before release; --allow-dirty is for testing only.'
        [[ $(git symbolic-ref --quiet --short HEAD) == main ]] || die 'Check out main before releasing.'
        git fetch origin || die 'Cannot fetch origin. Check network access and Git authentication.'
        git rev-parse --verify refs/remotes/origin/main >/dev/null 2>&1 || die 'origin/main is missing. Check the origin remote and fetch main.'
        git merge-base --is-ancestor refs/remotes/origin/main HEAD || die 'main is behind or diverged from origin/main. Reconcile reviewed changes before building; unpushed local commits are allowed.'
        if git show-ref --verify --quiet "refs/tags/v$VERSION"; then
            die "Local tag v$VERSION exists. Bump to an unused version."
        fi
        remote_tag=$(git ls-remote --tags origin "refs/tags/v$VERSION") || die 'Cannot check origin tags. Check network access and Git authentication.'
        [[ -z "$remote_tag" ]] || die "Origin tag v$VERSION exists. Bump to an unused version."
    else
        printf 'Testing: bypassing Git cleanliness, branch, sync, and tag checks.\n'
    fi
    identities=$(security find-identity -v -p codesigning) || die 'Cannot read signing identities. Unlock the login keychain.'
    printf '%s\n' "$identities" | grep -Eq '"Developer ID Application: .* \(P24JM6N5FP\)"$' ||
        die 'Install a valid Developer ID Application certificate and private key for P24JM6N5FP in the login keychain.'
    if [[ "$SKIP_NOTARIZE" == false ]]; then
        xcrun notarytool history --keychain-profile "$NOTARY_PROFILE" >/dev/null ||
            die "Notary profile '$NOTARY_PROFILE' is unavailable. Ask the owner to complete the documented one-time setup, or set NOTARY_PROFILE to an existing profile."
    fi

    local output="$ROOT/build/release/$VERSION"
    local archive="$output/DeviceDock.xcarchive" export_dir="$output/export" zip="$output/DeviceDock.zip"
    [[ ! -e "$archive" && ! -e "$export_dir" && ! -e "$zip" ]] || die "Existing output in $output. Move this directory aside before retrying."
    mkdir -p "$output"
    TEMP_DIR=$(mktemp -d "${TMPDIR:-/tmp}/DeviceDock-release.XXXXXX")
    printf 'Archiving DeviceDock %s (%s)…\n' "$VERSION" "$BUILD"
    # -quiet keeps warnings/errors visible; tee preserves diagnostics for failures.
    if ! xcodebuild archive -quiet -project DeviceDock.xcodeproj -scheme DeviceDock \
        -configuration Release -destination 'generic/platform=macOS' \
        -archivePath "$archive" -derivedDataPath "$output/DerivedData" \
        2>&1 | tee "$output/archive.log"; then
        die "Archive failed. Inspect $output/archive.log; resolve the Xcode error and move $output aside before retrying."
    fi
    if ! xcodebuild -exportArchive -quiet -archivePath "$archive" \
        -exportOptionsPlist "$ROOT/scripts/ExportOptions.plist" -exportPath "$export_dir" \
        2>&1 | tee "$output/export.log"; then
        die "Developer ID export failed. Inspect $output/export.log and the Xcode distribution logs; check signing and move $output aside before retrying."
    fi
    app="$export_dir/DeviceDock.app"
    [[ -d "$app" ]] || die "Export did not produce $app. Inspect $output/export.log."

    if [[ "$SKIP_NOTARIZE" == false ]]; then
        ditto -c -k --keepParent "$app" "$TEMP_DIR/notary.zip"
        # notarytool can exit nonzero for rejected submissions. Still read its JSON
        # and retrieve Apple's log whenever it supplies a submission ID.
        submit_exit=0
        xcrun notarytool submit "$TEMP_DIR/notary.zip" --keychain-profile "$NOTARY_PROFILE" \
            --wait --timeout 30m --output-format json >"$output/notary.json" || submit_exit=$?
        submission_status=$(plutil -extract status raw -o - "$output/notary.json" 2>/dev/null) || submission_status=Unknown
        submission_id=$(plutil -extract id raw -o - "$output/notary.json" 2>/dev/null) || submission_id=
        if [[ "$submission_status" != Accepted || "$submit_exit" != 0 ]]; then
            cat "$output/notary.json" >&2
            if [[ -n "$submission_id" ]]; then
                xcrun notarytool log "$submission_id" --keychain-profile "$NOTARY_PROFILE" || true
            fi
            die "Notarization did not finish successfully (status: $submission_status, exit: $submit_exit). Inspect Apple's log; do not distribute."
        fi
        xcrun stapler staple "$app"
    fi
    # Re-create the zip AFTER stapling so the distributed copy carries the ticket.
    ditto -c -k --keepParent "$app" "$zip"
    verify_app "$app"
    mkdir "$TEMP_DIR/unpacked"
    ditto -x -k "$zip" "$TEMP_DIR/unpacked"
    verify_app "$TEMP_DIR/unpacked/DeviceDock.app"
    printf '\nVersion: %s\nBuild: %s\nZip: %s\nSize (bytes): %s\nSHA-256: %s\n' \
        "$VERSION" "$BUILD" "$zip" "$(stat -f%z "$zip")" "$(shasum -a 256 "$zip" | awk '{print $1}')"
    if [[ "$SKIP_NOTARIZE" == true ]]; then
        printf 'TEST BUILD: notarization, stapling, and Gatekeeper checks were skipped. Do not publish.\n'
    fi
}

case "${1:-}" in
    --help|-h) usage ;;
    bump) shift; bump "$@" ;;
    build) shift; build_release "$@" ;;
    *) usage >&2; exit 1 ;;
esac
