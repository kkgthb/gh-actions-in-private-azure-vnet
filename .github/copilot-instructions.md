## Terraform style conventions

1. When creating Azure resources, if the underlying Azure resource type allows for hyphens, use the pattern `"${var.workload_nickname}-INSERTVERYSHORTNICKNAMEFORTHESERVICEHERE-demo"`.  So a resource group would be `"${var.workload_nickname}-rg-demo"`.  If it can't have such things, take out the hyphens.  If it has a length maximum, try chopping off `-demo` / `demo` first, and if still too long, try shortening up the nickname.
2. Make liberal use of `.tf` files, using standard naming conventions.  Don't just shove everything into `main.tf`.
3. When creating Azure resources, use the free-est/cheapest SKUs & settings possible, including using Linux wherever possible, because this is just a teaching demo, and I don't want to run up a big bill.