# Repository roles

Forgejo is the development source of truth. GitHub has two separate repositories:

| Repository | Visibility | Contents |
| --- | --- | --- |
| `TrackpadSwipe-dev` | Private | Forgejo development history, including intermediate commits |
| `TrackpadSwipe` | Public | Owner-approved release updates |

The development checkout uses `forgejo` for Forgejo, `origin` for the private mirror, and `public-release` for the public repository. Routine pushes to `public-release` are disabled in local Git configuration. Never bypass that guard for development updates.

After committing, run `scripts/sync-development.sh`. It pushes main and tags to Forgejo, fetches Forgejo’s main, and copies that history and tags to the private mirror. This is an explicit synchronization command, not a server-side scheduled mirror. The private mirror has Actions disabled; local native checks and public release CI remain available.

Public updates require the owner’s approval and a separate publication operation. Download hosting has not been selected; creating either repository does not authorize publishing binaries. The packaging and release checks are in [RELEASING.md](RELEASING.md).
