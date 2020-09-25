# CentOS

## Custom post-transaction hooks

Yum allows executing custom scripts with a post-action plugin. For that you
need to first install the plugin and then drop your actions in
`/etc/yum/post-actions/*.action`.

    yum install yum-plugin-post-transaction-actions

Check that it is [enabled](https://jsmith.fedorapeople.org/drafts/SMG/html/Software_Management_Guide/ch06s13.html) first.
You can find more information on the action usage [here](https://jsmith.fedorapeople.org/drafts/SMG/html/Software_Management_Guide/ch06s13s02.html).

A silly example executing upon any vim updates could look like this:

    vim*:any:bash -c "(date; id) > /tmp/post"
