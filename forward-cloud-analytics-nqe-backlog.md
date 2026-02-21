# Forward Cloud Analytics NQE Backlog

AWS-first cloud parity checks for the Skyforge Cloud Analytics overlay.

## Baseline checks
- `aws-sg-ingress-sensitive-ports.nqe`
- `aws-sg-ingress-any-service.nqe`
- `aws-sg-egress-any-service.nqe`

## Shipped competitive parity wave (2026-02-20)
1. `aws-sg-public-db-ports.nqe`
- Internet ingress to common datastore ports.

2. `aws-sg-unused-open-rules.nqe`
- Internet-any + any-service ingress on detached/unattached security groups.

3. `aws-sg-intra-vpc-lateral-any.nqe`
- RFC1918 east-west any-service exposure.

4. `aws-sg-ingress-overly-broad-cidrs.nqe`
- Broad non-/0 ingress CIDR exposure.

5. `aws-sg-egress-data-exfil-high-risk.nqe`
- Internet-any high-risk egress posture.

6. `aws-public-compute-with-admin-ports.nqe`
- Public compute attack surface via admin ports.

7. `aws-public-load-balancer-to-private-datastore.nqe`
- Public LB paths to private datastore backends.

8. `aws-cloud-account-cross-vpc-overexposure.nqe`
- Repeated open-pattern hotspots across VPCs in one account.

## Next-pass candidates
1. Add cloud-path context fields (`pathRefs`, `pathId`) from native Forward APIs into each finding row where available.
2. Add account-level trend deltas (new/resolved exposures by control) between processed snapshots.
3. Expand zero-input cloud checks for Azure/GCP equivalents after AWS check quality stabilizes.
