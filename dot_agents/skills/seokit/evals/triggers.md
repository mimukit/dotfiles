# seokit trigger cases

Run each prompt in a fresh session and record whether seokit fired. A near-miss that fires means the description is too broad; a should-fire case that stays quiet means a branch has no trigger.

## Should fire

**Page audit**

- "Do an SEO audit of https://example.com/pricing"
- "Audit the SEO of http://localhost:3000"
- "Run an SEO pass on the blog page locally"

**Pre-deploy local check**

- "Check SEO before I deploy"
- "Check SEO on my dev server before I ship this"

**Site crawl**

- "Crawl example.com and find SEO problems across the site"
- "Crawl my site for SEO issues, here's the sitemap: https://example.com/sitemap.xml"

**Ranking diagnosis**

- "Why isn't this page ranking? https://example.com/guides/widgets"
- "We migrated to Next.js and organic traffic dropped 40%"

**AI readiness**

- "Is my site ready for AI search or ChatGPT?"
- "Competitors show up in Google AI Overviews and we don't"

**Bot policy**

- "Should we block GPTBot in robots.txt?"
- "Check my robots.txt for AI bots"

**Re-audit**

- "I shipped the SEO fixes, re-check the page"
- "Did my SEO fixes land on localhost:3000?"

## Should not fire

- "Write a blog post about choosing a widget" (content writing)
- "Build 500 location landing pages for our keywords" (programmatic SEO)
- "Make this page load faster" with no search angle (performance work)
- "Add FAQ schema to the product template" (implementation: implementkit)
- "Make these docs read less like ChatGPT wrote them" (humankit)
