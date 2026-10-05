# Site-type playbooks

Read the one section that matches the site. Each gives the gaps that type usually has, the work worth planning next, and what not to do. A long-term plan item cites an entry here as `playbook: <type>, <entry>` when no finding covers it.

## SaaS and product sites

- **Usual gaps.** Feature pages thin on content; pricing rendered by client-side JavaScript or hidden behind "contact sales"; a blog that never links to the product pages; no comparison or alternatives pages; product facts that differ between the site, review platforms, and directory profiles.
- **Build next.** A pricing page whose plans, limits, and prices sit in the raw HTML; honest comparison pages that name the category leader and say where the product differs; docs and changelog pages crawlable and dated; one consistent product description across the About page, `Organization` markup, and third-party profiles (G2, Capterra, LinkedIn, Crunchbase).
- **Do not.** Publish self-ranked "best X" listicles as an emerging brand: answer engines cite them as category sources and then recommend the established competitors. Scale one landing page per keyword with swapped nouns.

## E-commerce

- **Usual gaps.** Thin category pages; manufacturer descriptions copied across the catalog; faceted navigation creating thousands of crawlable duplicates; out-of-stock pages deleted instead of kept; missing or wrong `Product` and `Offer` markup.
- **Build next.** Category pages with unique copy and internal links to subcategories; facet URLs controlled by canonical or `noindex` with a crawlable core set; `Product` markup with price, currency, and availability matching the page; a Merchant Center feed; return and shipping policy markup.
- **Do not.** Let every filter combination become an indexable URL. Remove a seasonal product page that has links; mark it unavailable instead.

## Content and blog sites

- **Usual gaps.** Old posts never refreshed; several posts competing for one query; no topical clusters; weak internal linking between related posts; no author pages; dates missing or bumped without edits.
- **Build next.** Cluster hub pages that link every post on a topic; merges of competing posts with redirects; author pages with credentials and `Person` markup; a refresh cadence for the posts that earn traffic; original data or first-hand examples on the posts that compete.
- **Do not.** Publish AI-generated posts at scale to cover more queries; Google's scaled content policy names it, and answer engines favor original sources. Change the date on a post without changing the post.

## Local business

- **Usual gaps.** Name, address, and phone that differ between the site, the Google Business Profile, and directories; no page per location; missing `LocalBusiness` markup; opening hours only in an image.
- **Build next.** One page per location with its own address, hours, map, and local content; `LocalBusiness` markup matching the Business Profile exactly; a review request routine; consistent citations in the main directories for the country.
- **Do not.** Create location pages for towns with no office (doorway pages). Buy or gate reviews.

## Documentation and developer sites

- **Usual gaps.** Client-rendered docs with empty raw HTML; versioned duplicates without canonicals; search-only navigation with no crawlable links; code samples as images.
- **Build next.** Static or server-rendered docs; a canonical to the current version from older versions; a sidebar of real links; an `llms.txt` index of the docs, since coding assistants do fetch docs directly; question-shaped headings for common errors and tasks.
- **Do not.** Block `ChatGPT-User` or `Claude-User`: developers ask assistants to read the docs on their behalf.

## Personal sites and portfolios

- **Usual gaps.** A single-page site with one title for everything; work samples with no text; no `Person` markup; a name spelled differently across profiles.
- **Build next.** One page per major project with a description of the problem and the result; `Person` markup with `sameAs` to the main profiles; a consistent name and one-line description everywhere.
- **Do not.** Rely on a PDF résumé as the only text about the person.
