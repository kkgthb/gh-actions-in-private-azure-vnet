## Notes

### Azure NSG details

I don't know if my Azure Network Security Group Security Rules are architected exactly the way I'd want to spec them out in an enterprise setting.  The notes I used about all that were copied and pasted from some early doodles I was pondering as I combed the GitHub docs, so don't put too much weight into studying them.

Honestly, I don't particularly care, as all I am really trying to test with this repo is whether I could attach an `ubuntu-latest` GitHub "runner" to a GitHub "runner group" that's attached to a GitHub "hosted compute network configuration" entry that's attached to an Azure `GitHub.Network/networkSettings` resource, because at least as of 3/13/26, GitHub's documentation is unclear.

### GitHub runner

Sadly, the GitHub organization in which I was testing ... was out of Actions budget.

But I managed to get `https://github.com/ORGNAME/REPONAME/actions/runs/RUNID/job/JOBID` to show this:

```
Evaluating job_1.if
Evaluating: success()
Result: true
Requested labels: redstaplerrn
Job defined at: ORGNAME/REPONAME/.github/workflows/demo_workflow.yml@refs/heads/main
Waiting for a runner to pick up this job...
```

_(Note `redstaplerrn` in it.)_

And `https://github.com/ORGNAME/REPONAME/actions/runners`, under its GitHub-hosted runners tab, shows 2 available runners:

1. "Standard GitHub-hosted runners" with "..." offering to help me copy `ubuntu-latest`, `windows-latest`, or `mac-latest`
2. "(my runner name)" with "..." offering "Copy label" and pasting it returning `(my runner name)`.

Soooo ... ummmmm ... yeah.  At the very least, yes, I think I demonstrated that `ubuntu-latest` _(currently image ID `2306`)_ is provisionable just fine, even into a GitHub "runner group" that's attached to a "Network Configuration" that's attached to an Azure VNET.  No need, from what I can tell, to end up in the "large runner" `linux_2_core_advanced` SKU that has no free minutes included when the `actions_linux` SKU with its oodles of free GitHub Actions "minutes" will do.  _(Apparently some LLMs will try to convince you `actions_linux` isn't possible, but I think that's a misreading of Microsoft's docs.  I feel like it wouldn't even provision if it weren't possible.)_