# kubectl

This action will install `kubectl`, if necessary (courtesy of the [bininstall]
action) and interact with a Kubernetes cluster. The downloaded `kubectl` binary
is cached per project and runner to ease on bandwidth and speed execution,
especially when several calls to `kubectl` need to be performed. `kubectl` is a
"fat" binary, meaning that the downloaded binary should work in most Linux-based
runners, whichever the underlying distribution is, including [Alpine].

  [bininstal]: https://github.com/efrecon/bininstall
  [Alpine]: https://www.alpinelinux.org/

## Usage

This action is designed to have good defaults. It recognises cluster and
authentication information details through a varying set of inputs, and will
then behave as if the content of the input field `args` had been given to
`kubectl` at the command-line. For a complete list of all inputs, see
[action.yml](./action.yml).

In order to perform several calls to this action in a workflow, you will have to
provide authentication details every time. However, you can use YAML [anchors]
to avoid repeating yourself.

  [anchors]: https://www.educative.io/blog/advanced-yaml-syntax-cheatsheet#anchors

### Authentication with Kubeconfig File

The following workflow step would authenticate and authorise using the content
of the secret called `KUBECONFIG`.  This action will attempt to automatically
detect the content of the data passed to the `config` input: the path to a file,
a base64 encoded kubeconfig or the YAML with the content of the kubeconfig file
(in this order).

```yaml
-
  uses: Mitigram/gh-action-kubectl@master
  with:
    config: ${{ secrets.KUBECONFIG }}
    args: cluster-info
```

### Authentication with Credentials

The following workflow step would authenticate and authorise using the username
and password from the `K8S_USERNAME` and `K8S_PASSWORD` secrets, against the
cluster at host `K8S_HOST` and with CA certificate `K8S_CERT`. This action will
attempt to automatically detect the content of the data passed to the
`certificate` input: the path to a file, a base64 encoded kubeconfig or the YAML
with the content of the kubeconfig file (in this order).

```yaml
-
  uses: Mitigram/gh-action-kubectl@master
  with:
    host: ${{ secrets.K8S_HOST }}
    certificate: ${{ secrets.K8S_CERT }}
    username: ${{ secrets.K8S_USERNAME }}
    password: ${{ secrets.K8S_PASSWORD }}
    args: cluster-info
```

## Authentication with a Bearer Token

The following workflow step would authenticate and authorise using the bearer
token from the `K8S_TOKEN` secret, against the cluster at host `K8S_HOST` and
with CA certificate `K8S_CERT`. This action will attempt to automatically detect
the content of the data passed to the `certificate` input: the path to a file, a
base64 encoded kubeconfig or the YAML with the content of the kubeconfig file
(in this order).

```yaml
-
  uses: Mitigram/gh-action-kubectl@master
  with:
    host: ${{ secrets.K8S_HOST }}
    certificate: ${{ secrets.K8S_CERT }}
    token: ${{ secrets.K8S_TOKEN }}
    args: cluster-info
```

## Output

This action provides two outputs:

+ `version` is the version of the `kubectl` that was used by the action. This
  will be a semantic version, i.e. `<major>.<minor>.<patch>`, `1.22.2`.
+ `output` is the result of the `kubectl`, so that your workflow can make use of
  this output further below.
