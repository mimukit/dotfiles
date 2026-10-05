# Structured data: eligibility and templates

Read this when `DATA-VALID` or `DATA-ENTITY` needs a fix, or a page type has no markup. Markup describes what is visible on the page; a type added only to win a rich result breaks Google's guidelines.

## Eligibility, as of 2026-10

Check Google's [search gallery](https://developers.google.com/search/docs/appearance/structured-data/search-gallery) before recommending a type, because the list changes. At this date it holds Article, Breadcrumb, Carousel, Course list, Dataset, Discussion forum, Education Q&A, Employer aggregate rating, Event, Image metadata, Job posting, Local business, Math solver, Movie, Organization, Product, Profile page, Q&A, Recipe, Review snippet, Software app, Speakable, Subscription and paywalled content, Vacation rental, Video, Book actions, Fact check, Loyalty program, and the Merchant listing, return policy, and shipping policy types.

Gone from the gallery, so never promised as a Google rich result:

- **FAQ.** Limited to authoritative government and health sites in August 2023; Google stopped showing FAQ rich results on 2026-05-07 and removed the Search Console report in June 2026. `FAQPage` markup stays valid, and Bing and some AI crawlers still read it. Keep existing markup that matches visible Q&A; add it for those readers, never for a Google feature.
- **HowTo.** Rich results removed in 2023.
- **Sitelinks search box.** Removed in late 2024; `WebSite` with `SearchAction` earns nothing in Google now.

Google's AI features need no special markup. Structured data helps every engine identify the entity, the author, and the dates; it is not a ticket into AI answers.

## What to check per type

| Type | Required for a Google feature | Worth adding for every engine |
|------|-------------------------------|-------------------------------|
| `Article`, `BlogPosting`, `NewsArticle` | none strictly; `headline`, `image`, `datePublished` recommended | `author` as a `Person` with `url`, `dateModified` |
| `BreadcrumbList` | `itemListElement` with `position`, `name`, `item` | matches the visible breadcrumb |
| `Product` | `name` plus one of `offers`, `review`, `aggregateRating` | `offers.price`, `priceCurrency`, `availability` |
| `Organization` | none strictly; `logo` and `url` recommended | `sameAs` to official profiles, `name` equal to the brand everywhere |
| `LocalBusiness` | `name`, `address` | `telephone`, `openingHoursSpecification`, `geo`; name, address, and phone identical to the Business Profile |
| `SoftwareApplication` | `name`, `offers.price` (0 is valid), plus `aggregateRating` or `review` | `applicationCategory`, `operatingSystem` |
| `Person` (profile, author) | inside `ProfilePage` for that feature | `jobTitle`, `sameAs`, `knowsAbout` |

Use absolute URLs and stable `@id` values (`https://example.com/#organization`) so pages can reference one entity instead of repeating it.

## Templates

One `@graph` per page keeps the entities linked. Replace every value with what the page shows.

```json
{
  "@context": "https://schema.org",
  "@graph": [
    {
      "@type": "Organization",
      "@id": "https://example.com/#organization",
      "name": "Example",
      "url": "https://example.com/",
      "logo": "https://example.com/logo.png",
      "sameAs": ["https://www.linkedin.com/company/example", "https://github.com/example"]
    },
    {
      "@type": "WebSite",
      "@id": "https://example.com/#website",
      "url": "https://example.com/",
      "name": "Example",
      "publisher": { "@id": "https://example.com/#organization" }
    },
    {
      "@type": "BlogPosting",
      "headline": "How to choose a widget",
      "image": "https://example.com/images/widget.jpg",
      "datePublished": "2026-09-01",
      "dateModified": "2026-09-20",
      "author": { "@type": "Person", "name": "Jane Doe", "url": "https://example.com/team/jane" },
      "publisher": { "@id": "https://example.com/#organization" },
      "mainEntityOfPage": "https://example.com/blog/choose-a-widget"
    },
    {
      "@type": "BreadcrumbList",
      "itemListElement": [
        { "@type": "ListItem", "position": 1, "name": "Blog", "item": "https://example.com/blog/" },
        { "@type": "ListItem", "position": 2, "name": "How to choose a widget", "item": "https://example.com/blog/choose-a-widget" }
      ]
    }
  ]
}
```

```json
{
  "@context": "https://schema.org",
  "@type": "Product",
  "name": "Blue Widget",
  "image": "https://example.com/images/blue-widget.jpg",
  "description": "Chrome-finish widget with a side control panel.",
  "sku": "BW-100",
  "brand": { "@type": "Brand", "name": "Example" },
  "offers": {
    "@type": "Offer",
    "url": "https://example.com/products/blue-widget",
    "price": "49.00",
    "priceCurrency": "USD",
    "availability": "https://schema.org/InStock"
  }
}
```

```json
{
  "@context": "https://schema.org",
  "@type": "LocalBusiness",
  "name": "Example Plumbing",
  "url": "https://example.com/",
  "telephone": "+1-555-010-0000",
  "address": {
    "@type": "PostalAddress",
    "streetAddress": "1 Main St",
    "addressLocality": "Springfield",
    "postalCode": "00000",
    "addressCountry": "US"
  },
  "openingHoursSpecification": [
    { "@type": "OpeningHoursSpecification", "dayOfWeek": ["Monday", "Tuesday", "Wednesday", "Thursday", "Friday"], "opens": "08:00", "closes": "18:00" }
  ]
}
```

## Validating

Run Google's [Rich Results Test](https://search.google.com/test/rich-results) on a public URL, or paste the rendered code for a local page; it renders JavaScript, so it sees injected blocks that raw HTML misses. The [Schema Markup Validator](https://validator.schema.org/) checks schema.org syntax for every engine. Passing either proves eligibility at most, never display.
