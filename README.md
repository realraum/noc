# realraum.at -- Network of Chaos

This repository is hosted on [`git.realraum.at`] and on [Github].
It contains documentation and scripts used for managing the network
in [Realraum], an Austrian hackerspace.

The copy on [Github] is (currently) deemed authoritative, to provide
(basic) issues-tracking and PR review tools.  To push to both locations
simultaneously, use the following `.git/config` snippet:

	[remote "origin"]
		url = git@git.realraum.at:noc
		url = github.com:realraum/noc

In the longer-term, we should setup an internal issues-and-review tool.


[`git.realraum.at`]: https://git.realraum.at/?p=noc.git;a=summary
[Github]:            https://github.com/realraum/noc
[Realraum]:          https://realraum.at


## Development process

There is (currently) no barrier to pushing directly to `master`.  However,
NOC members are welcome to submit pull requests to ask for review/feedback.

Of course, “force-pushing” to `master` is not allowed, whether on
`git.realraum.at` or Github.


## Documentation

The documentation is located in the `doc/` directory, in a format that
can be rendered by [Ikiwiki], a static site generator.


## Ansible

Ansible scripts, previously found on `git.realraum.at:ansible`,
are located in the `ansible/` directory.  Documentation related to the
use of Ansible and related scripts is foind there.
