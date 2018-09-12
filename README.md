# ppx_make_record

> Unreleased

This syntax extension complements the deriving "make" plugin. It allows to use
the convinient record syntax to make record values using the record constructor
function `make`. In particular it is useful for large nested configuration DSLs
where the regular function application syntax might be cumbersome to use
because of the dangling `()` required for optional argument erasure.


## Installation

Install the extension with OPAM.

```
$ opam install ppx_make_record
```

Add the preprocessor directive to your project's `dune` file:

```lisp
(executable
  (name My_app)
  (public_name my-app)
  (preprocess (pps ppx_make_record)))
```


## Examples

Consider this example in ReasonML for a Kubernetes deployment. The translation
is only applied in the `let` binding annotated with `make`.

```reason
let%make main = (~namespace, ~version) =>
  Deployment {
    api_version: "extensions/v1beta1",
    kind: "Deployment",
    metadata: Meta { name, namespace },
    spec: Deployment_spec {
      replicas: 1,
      template: Pod_template_spec {
        metadata: Meta {
          name,
          labels: [("app", name)],
          annotations: Std.Prometheus.(annotations(Config.port))
        },
        spec: Pod_spec {
          containers: [
            Container {
              name,
              image: Std.ecr("my-company/my-app", ~label=version),
              command: ["app"],
              args: [
                "--verbosity=debug",
                "--listen-prometheus=" ++ Int.to_string(Std.Prometheus.Config.port),
              ],
              ports: [Std.Prometheus.(port(Config.port))],
              resources: Resources {
                limits:   [cpu("100m"), memory("500Mi")],
                requests: [cpu("500m"), memory("1Gi")]
              }
            }
          ]
        }
      }
    }
  };
```

This is translated by the preprocessor into:

```reason
let main = (~namespace, ~version) =>
  Deployment.make(
    ~api_version="extensions/v1beta1",
    ~kind="Deployment",
    ~metadata=Meta.make(~name, ~namespace, ()),
    ~spec=Deployment_spec.make(
      replicas: 1,
      template: Pod_template_spec.make(
        ~metadata=Meta.make(
          ~name,
          ~labels=[("app", name)],
          ~annotations=Std.Prometheus.(annotations(Config.port)),
          ()
        ),
        ~spec=Pod_spec.make(
          ~containers: [
            Container.make(
              ~name,
              ~image=Std.ecr("my-company/my-app", ~label=version),
              ~command=["app"],
              ~args=[
                "--verbosity=debug",
                "--listen-prometheus=" ++ Int.to_string(Std.Prometheus.Config.port),
              ],
              ~ports-[Std.Prometheus.(port(Config.port))],
              ~resources=Resources.make(
                limits:   [cpu("100m"), memory("500Mi")],
                requests: [cpu("500m"), memory("1Gi")],
                ()
              ),
              ()
            )
          ],
          ()
        ),
        ()
      ),
      ()
    ),
    ()
  );
```