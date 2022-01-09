=================
oci-domeneshop-le
=================

I have a small k3s cluster on Oracle Cloud, and want to use Let's Encrypt for certificates on the Load Balancer.
I use Domeneshop for my DNS, and they support Let's Encrypt via a provider for certbot.

This project is basically connecting all these dots together into something that can run in the k3s cluster.

TODO
----

[ ] Set up credentials for OCI SDK
[ ] Set up credentials for Certbot + Domeneshop
[ ] Decide on how to keep certificates (Longhorn?)
