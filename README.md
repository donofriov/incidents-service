# incidents-service

## Task 1 / Task 2

Run the init script to setup the entire service is a local kind kubernetes cluster:

> Note: Assumes docker, kubectl, and helm are installed on your machine. Kind will be installed as part of the init script if it doesn't exist.

```bash
git clone https://github.com/donofriov/incidents-service.git
cd incidents-service
bin/init
```

To update environment variables, edit the [`envVars` object (map) in `provisioning/k8s/values.yaml`](https://github.com/donofriov/incidents-service/blob/08a6724a34ea5d491176d334ebda53a4c3a8b5fd/provisioning/k8s/values.yaml#L3-L5)

To update incidents, edit the [`incidents` array (sequence) in `provisioning/k8s/values.yaml`](https://github.com/donofriov/incidents-service/blob/08a6724a34ea5d491176d334ebda53a4c3a8b5fd/provisioning/k8s/values.yaml#L7-L19)

If application code as well as chart code was changed, run:

```bash
bin/deliver 0.2.0
```

Where `0.2.0` is the next release version (using semantic versioning, select the applicable major, minor, patch version based on what changed). This script will generate a new release and deploy it to the cluster.

If only the chart values changed, run:

```bash
bin/deploy 0.1.0
```

Where `0.1.0` is the currently deploy release version. This will update the chart values without having to rebuild the docker image.

The app can be run also be run directly on your machine:

```bash
cd app/
bundle install
ruby incidents.rb
```

Or in a docker container:

```bash
docker run --rm -p 3000:3000 incidents-service:0.1.0
```

## Task 3

What is needed to achieve high availability during restarts and reschedulings for this
application with Kubernetes?

I'd deploy it as a StatefulSet with PersistentVolumes fronted by a headless service for peer discovery and a gRPC ingress for clients. Each replica would run on a separate node using anti-affinity and would be protected by a PodDisruptionBudget ensuring at least two nodes always stay up.

I'd add graceful termination hooks so Erlang nodes leave the ring cleanly, use readiness probes that confirm cluster membership before serving traffic and OrderedReady rolling updates so only one pod restarts at a time.

Together these ensure that during restarts or maintenance, the cluster remains available and consistent with Dynamo's guarantees.

## Task 4

How
can we achieve this? What would be required of the external company?

I'd use AWS PrivateLink. We'd need to create a VPC Endpoint Service pointing at the NLB, update it to add the allowed principle which would be arn:aws:iam::<EXTERNAL_ACCOUNT_ID>:root, then share the service name with the external company as well as availability zone ids to avoid cross-AZ data charges.

The external company would need create interface endpoints in each AZ they want, then accept the vpc endpoint connection using our service id and their vpc endpoint ids. They could create a CNAME record if desired.

## Task 5

The quickest/easiest way I'd implement this would be in GitHub Actions. An alternative would be AWS Lambda/EventBridge Scheduler/Secrets Manager which could be more production ready but is more moving parts.

See workflow [code](https://github.com/donofriov/incidents-service/blob/55846bf49263dd46dd9cf0cc0539dc4a94e194e6/.github/workflows/task-5.yml) and [run](https://github.com/donofriov/incidents-service/actions/runs/18325256626)
