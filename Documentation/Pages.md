# Publish and verify the documentation domain

Use this guide to publish one current development site at
`https://kiteconnect.ankitgoyal.io`. The site retains the package's partial 0.x
status. There are no archived sites or version selector.

## Configure GitHub Pages

1. Open [repository Pages settings](https://github.com/ankitgoyalio/swiftkiteconnect/settings/pages).
   Select **GitHub Actions** as the source. Set the custom domain to
   `kiteconnect.ankitgoyal.io`. With Actions, the repository setting controls the
   domain. The artifact's `CNAME` alone does not configure it.
2. Open the repository's **Environments** settings. Select `github-pages` and
   restrict deployment branches to the branch `main`. Do not allow tags or
   integration branches.
3. Keep the `apple` and `ubuntu` required checks in the `main` ruleset.
   Publication also depends on both jobs within the same workflow run and commit.
   Keep ordinary validation permissions at `contents: read`. Only `deploy` receives
   `pages: write` and `id-token: write`.

Inspect settings without deploying:

```fish
gh api repos/ankitgoyalio/swiftkiteconnect/pages
gh api repos/ankitgoyalio/swiftkiteconnect/environments/github-pages/deployment-branch-policies
gh api repos/ankitgoyalio/swiftkiteconnect/rulesets
```

Creating a Pages configuration does not publish the integration branch. Do not
trigger a Pages build or upload an integration artifact to bypass qualification.
The workflow publishes only `push` events on `refs/heads/main`. Manual runs and
pull requests perform validation only. Failed, cancelled, or skipped qualification
jobs prevent deployment. Failed validation leaves the previous deployment intact.

## Configure the dedicated DNS record

1. In the GitHub account's **Settings > Pages**, add `ankitgoyal.io` for domain
   verification. If GitHub already marks the domain verified, retain that setting.
2. Copy the exact TXT name and value GitHub supplies to the DNS provider. For this
   account and apex domain, the name is
   `_github-pages-challenge-ankitgoyalio.ankitgoyal.io`. Complete verification in
   GitHub and retain the TXT record. Apex verification protects immediate
   subdomains, including `kiteconnect.ankitgoyal.io`.
3. In the authoritative DNS provider, add only this package record:

   | Type | Name | Target |
   | --- | --- | --- |
   | CNAME | `kiteconnect` | `ankitgoyalio.github.io` |

   Use DNS-only mode if Cloudflare manages the zone. Do not point the CNAME at a
   URL or add `/swiftkiteconnect`. Do not add a wildcard. If this exact name already
   has records, inspect them before replacing anything.
4. Preserve the personal website's apex and `www` records, nameservers, mail
   records, and unrelated verification records. Domain verification adds a TXT
   record. It does not require moving the personal website to GitHub Pages.
5. Inspect propagation and compare the CNAME with the target above:

   ```fish
   dig ankitgoyal.io NS +short
   dig kiteconnect.ankitgoyal.io CNAME +noall +answer
   dig @1.1.1.1 kiteconnect.ankitgoyal.io CNAME +noall +answer
   dig _github-pages-challenge-ankitgoyalio.ankitgoyal.io TXT +short
   ```

DNS changes require access to the authoritative zone. Without that access,
record DNS as an external deployment dependency. An absent TXT answer does not
establish whether GitHub previously verified the account's domain. Inspect the
account setting before claiming verification.

## Enable HTTPS and make the initial publication

1. Wait for the repository's Pages DNS check and certificate provisioning to
   complete. Check the Pages API's `https_certificate` state if provisioning stalls.
   Use GitHub's [custom-domain troubleshooting guide](https://docs.github.com/en/pages/configuring-a-custom-domain-for-your-github-pages-site/troubleshooting-custom-domains-and-github-pages)
   before changing DNS records.
2. Enable **Enforce HTTPS** in Pages settings after the certificate exists.
   Inspect `https_enforced` through the Pages API. Do not bypass TLS validation.
3. After review, let the changes reach `main` through the normal merge process.
   Both qualification jobs must succeed before `deploy` can run. The Apple job
   includes documentation integrity, complete public declaration coverage,
   warning-free DocC conversion, compiled examples, offline Publisher tests,
   macOS tests, and iOS Simulator tests. Ubuntu qualification remains required.
4. Confirm that the `deploy` job succeeds for that `main` commit. Download the
   `docc-site` artifact from that exact run into an ignored directory:

   ```fish
   gh run list --branch main --workflow protocol-tests.yml
   gh run view RUN_ID
   gh run download RUN_ID --name docc-site --dir .test-results/pages-artifact
   tar -xf .test-results/pages-artifact/docc-validation.tar -C .test-results/pages-artifact
   python3 Scripts/check-documentation-site.py .test-results/pages-artifact/site
   python3 Scripts/check-documentation-live.py .test-results/pages-artifact/site
   ```

   Replace `RUN_ID` with the successful run's numeric ID. The validation artifact
   contains `docc-validation.tar`, which preserves DocC's colon-bearing symbol
   filenames. Extracting the tar file produces `site`, `KiteConnect.doccarchive`,
   and `public-api-inventory.json`.
   The live checker requires public HTTPS trust, HTTP 200 responses, expected
   HTML and JSON content types, and bytes matching the supplied artifact. It
   checks the root landing page, direct symbol and article pages, tutorial
   overview and first request, repeated requests and slash redirects, page data,
   renderer chunks, tutorial resources, and navigation/search data.
5. Open the domain root in a browser and confirm that it opens the package
   overview with visible development and partial 0.x status. Open and reload:

   - `/documentation/kiteconnect/kiteclient/`
   - `/documentation/kiteconnect/create-a-client/`
   - `/tutorials/getting-started/`
   - `/tutorials/kiteconnect/first-request/`

   Search for `KiteClient` in DocC and open the result. Check tutorial images and
   code downloads. The HTTP checker verifies search data and scripts. This browser
   check verifies the interactive search and navigation behavior.
6. Record the deployment URL, commit, and verification result in the issue or PR.
   Keep raw output in CI artifacts or `.test-results/`. Update
   [verification status](Verification.md) only when qualification changes.

Do not describe the domain as live until deployment, DNS, HTTPS, and the checks
above succeed. None of these checks requires Kite credentials or trading requests.

## Maintain the current site

For each `main` push, use the workflow result and Pages deployment history to
identify the published commit. To investigate a failed update, inspect the failed
job and retain the current deployment while fixing the source. Submit fixes through
normal validation. To restore older content, revert the source change through a
reviewed commit and let the successful `main` workflow republish it.

Keep generated site output outside Git. Recheck the direct routes and interactive
search after toolchain, renderer, workflow, or domain changes. Revisit versioning
when the first release is tagged.

GitHub documents [Actions publication](https://docs.github.com/en/pages/getting-started-with-github-pages/using-custom-workflows-with-github-pages),
[custom domains](https://docs.github.com/en/pages/configuring-a-custom-domain-for-your-github-pages-site/managing-a-custom-domain-for-your-github-pages-site),
and [domain verification](https://docs.github.com/en/pages/configuring-a-custom-domain-for-your-github-pages-site/verifying-your-custom-domain-for-github-pages).
