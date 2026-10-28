# Publish package documentation with DocC

Use DocC for the package's public documentation, with its standard website presentation. Write for developers who know Swift and `async/await`, and introduce the Kite Connect concepts they need. The first documentation release will include public API reference, a guided first read-only request, task guides, and explanations of authentication and streaming.

DocC keeps the API reference connected to Swift symbols and supports articles and tutorials in the same documentation site. This choice commits the authored content to DocC markup rather than a separate documentation framework.

DocC will be the canonical home for user-facing guides. The README will provide a short introduction and links. Release evidence, coverage checklists, and upstream snapshots will remain repository documents. This separation avoids maintaining duplicate guides.

The documentation release requires meaningful documentation for every public declaration. Document behavior, parameters, return values, errors, and relevant constraints where applicable. The introductory tutorial will use DocC's native step-by-step format and cover installation, authentication, and a read-only user-profile request, with code and expected results at each step. Task guides will be shorter articles.

CI will require a successful DocC build with no documentation warnings and compiled Swift examples. Preserve the existing example checks as content moves. Routine checks will use fixtures and require no live credentials.

Host the generated site on GitHub Pages at `kiteconnect.ankitgoyal.io`. A dedicated package subdomain keeps its deployment separate from the existing personal website and leaves `docs.ankitgoyal.io` available for other projects.

Initially, publish one current documentation version from successful builds of `main`, clearly labelled as development documentation. Validate pull requests without publishing them. Older release sources will remain in Git; archived websites and a version selector are deferred until needed. Revisit the public default when the first release is tagged.
