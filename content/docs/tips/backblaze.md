# Backblaze

## Manually Sync

For example to additionally store my GitLab backups on Backblaze:

- move all relevant files to a folder
- (optionally) encrypt all files
- run `b2 sync . b2://bucketname/`

### GitLab Backups

My GitLab backups are currently stored in a Minio S3 object storage with WORM activated but files
can still be deleted by accident from the server itself. A naiive workflow would look like this:

Mirror all files from Minio locally:

    tmp
    mc mirror rz/gitlab/ ./

Encrypt all files with GPG and remove plaintexts:

    for f in $(ls !(*.gpg)); do \
      gpg --recipient ansemjo --encrypt $f; \
      rm -fv $f; \
    done;


Mirror encrypted files to Backblaze:

    # check file list
    b2 sync --dryRun --compareVersions none ./ b2://gitbacks/

    # upload to backblaze
    b2 sync --compareVersions none ./ b2://gitbacks/

The `--compareVersions none` is needed since GPG does not create stable filesizes and the naiive
approach obviously creates newer modification times. Unless there are problems during upload, the
filename should be a stable enough distinction though.
