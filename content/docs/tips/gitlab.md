---
title: GitLab
weight: 10
---

# GitLab

## Gitlab Runner in QEMU/KVM

First [deploy CoreOS in a virtual machine](../rechenzentrum/docker-in-kvm.md).

Then deploy the Gitlab Runner as a Docker container itself. Following the
[documentation](https://docs.gitlab.com/runner/install/docker.html):

    docker run -d --name runner --restart always \
      -v /etc/gitlab-runner:/etc/gitlab-runner \
      -v /var/run/docker.sock:/var/run/docker.sock \
      gitlab/gitlab-runner:alpine
    docker exec -it runner register

{{< hint warning >}}
You may need to install your CA certificate both on the CoreOS VM as well as in the
runner configuration first:

```sh
scp /etc/ipa/ca.crt runner:
ssh runner
sudo mv ca.crt /etc/ssl/certs/my-ca.pem
sudo update-ca-certificates
sudo mkdir -p /etc/gitlab-runner/certs
sudo cp /etc/ssl/certs/my-ca.pem /etc/gitlab-runner/certs/ca.crt
```

Reboot the VM and/or restart the Docker service afterwards.
{{< /hint >}}

## Gitlab API

[Official Documentation](https://docs.gitlab.com/ee/api/README.html) is available with all the v4
API routes.

### Bash Alias

A useful bash alias for `httpie` to interact with the GitLab API:

```bash
gitlab() {
  meth=${1:?http method};
  api=${2:?api path};
  shift 2;
  http --check-status \
    "$meth" "https://git.rz.semjonov.de/api/v4/$api" \
    private-token:"$TOKEN" \
    "$@";
}
```

Then export your [personal access token](https://git.rz.semjonov.de/profile/personal_access_tokens)
to env:

```
read TOKEN && export TOKEN
```

### Usage

Chained to `jq`, the usage becomes:

```bash
$ gitlab GET projects | jq 'map(.name)'
[
  "deploy",
  "bookstack",
  "preseedinjector",
  "frontend",
  "sbupdate",
  "..."
]
```

```bash
$ gitlab PUT projects/11 wiki_enabled=false
HTTP/1.1 200 OK
Cache-Control: max-age=0, private, must-revalidate
Connection: keep-alive
Content-Length: 2022
Content-Type: application/json
Date: Fri, 27 Jul 2018 13:41:41 GMT
...
```

### Examples

#### Get the Wiki Status

A stupid loop to get the `wiki_enabled` status of projects:

```bash
for i in {1..116}; do
  project=$(gitlab GET projects/$i 2>/dev/null) \
  && wiki=$(jq .wiki_enabled <<<"$project") \
  && path=$(jq .path_with_namespace <<<"$project") \
  && echo "$i $path: $wiki";
done
```
