---
name: literature-search
description: Search the scientific literature and answer from it without invented or second-hand sources - the Zotero library first, then the asta (Semantic Scholar), pubmed and arxiv MCP servers, web search last. Use whenever the user asks what is known about a topic, asks for papers, sources or evidence, wants related work found, or asks whether the literature supports a claim. To check an existing bibliography use citation-check; for notes on one paper use research-litnote.
---

# Literature search

## Search order

1. **Zotero** (see the zotero-cli skill). What the user saved and annotated
   comes first; note which hits have a PDF you can `read`.
   ```bash
   zotero-cli --json search "<query>" --all-libraries --limit 20 --detail keys_only
   zotero-cli --json search --mode semantic "<idea>"   # only if `db status` shows an index
   ```
2. **Databases**, through the MCP servers. Query at least two for a topic
   question; they index different things.
   - `asta` (Semantic Scholar, all fields): `search_papers_by_relevance`,
     `snippet_search` for passages from paper bodies, `get_citations`.
   - `pubmed` (biomedicine, neuroscience): `pubmed_search_articles` (MeSH
     terms from `pubmed_lookup_mesh`), `pubmed_europepmc_search` for
     preprints, `pubmed_fetch_fulltext`, `pubmed_find_related`.
   - `arxiv` (ML, computer vision): `search_papers`, `get_paper_outline`,
     `read_paper_section`, `citation_graph`.
3. **Web search** last, for what the databases lack (code, datasets,
   workshop papers). Label those results as web-found.

A server that is missing or failing (asta needs `ASTA_API_KEY`) is named in
the answer; carry on with the others. Never fill the gap from memory.

## Where each claim comes from

Every reference in an answer carries an identifier seen this session:
Zotero key, DOI, PMID or arXiv id. Mark what backs each claim:

- `[read p. 4]` or `[read §3.2]`: you read that passage (zotero `read`,
  `pubmed_fetch_fulltext`, arxiv `read_paper_section`, asta `snippet_search`).
- `[abstract]`: only the abstract or a database summary.
- `[memory, unchecked]`: you recall it but did not find it this session.
  Such a reference gets no DOI, page number or quote.

Methods, numbers, sample sizes, quotes, subgroup results and limitations
need `[read]`. Abstracts overstate; do not fill those in from one.

## Traps

- **Second-hand citations.** A claim you met in a review or an
  introduction is cited as "Smith 2020, as cited in Jones 2023" until you
  have read Smith 2020 itself.
- **Versions.** arXiv v1 is not the final paper, a preprint is not peer
  reviewed, a workshop paper is not the main track, and an OpenReview
  rejection is not a publication. Cite the version you read.
- **Retractions and corrections.** Check a DOI before you recommend or
  cite it. `type` is `retraction`, `correction` or `expression_of_concern`;
  report any you find. `relation` shows `is-preprint-of` / `has-preprint`.
  ```bash
  curl -s "https://api.crossref.org/works/<DOI>" \
    | jq '.message | {updated_by: (.["updated-by"] // [] | map({type, DOI})), relation}'
  ```
- **Popularity.** Citation counts favour old and famous papers. Do not rank
  by them alone; say how you ranked.
- **Neuroscience claims.** Give species, preparation (in vivo, in vitro,
  post-mortem) and sample size. Correlational imaging is not causal. Name
  areas by the atlas the paper used: Julich-Brain, Brodmann and other
  parcellations draw the same names differently.
- **Absence.** "No paper on X" holds only for the databases and queries
  you ran.

## End every search with a coverage line

Databases queried, queries, date run, filters, and what was not searched
(paywalled full text, Google Scholar, proceedings outside these indexes).

## After the search

- Add papers to Zotero only when the user asks:
  `zotero-cli add doi <DOI> -c "<collection>"`.
- **citation-check** finds no `reference-lookup` tools here. Its lookups
  are asta `search_paper_by_title`, `pubmed_lookup_citation` (25 at a time)
  and the Crossref call above.
- Only citation-check and research-litnote are installed from Research
  Desk. Skip their hints to paper-compare, related-work and paper-critique.
