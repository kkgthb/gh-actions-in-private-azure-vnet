## Notes

I don't know if my Azure Network Security Group Security Rules are architected exactly the way I'd want to spec them out in an enterprise setting.  The notes I used about all that were copied and pasted from some early doodles I was pondering as I combed the GitHub docs, so don't put too much weight into studying them.

Honestly, I don't particularly care, as all I am really trying to test with this repo is whether I could attach an `ubuntu-latest` GitHub "runner" to a GitHub "runner group" that's attached to a GitHub "hosted compute network configuration" entry that's attached to an Azure `GitHub.Network/networkSettings` resource, because at least as of 3/13/26, GitHub's documentation is unclear.