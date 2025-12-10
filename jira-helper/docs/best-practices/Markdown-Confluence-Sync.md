# PANK-1485: Bidirectional Markdown ↔ Confluence Sync Guide

## Problem Summary

When converting Confluence pages to Markdown and back, code block formatting was getting corrupted. The issue was identified and fixed.

## What Was Wrong

### Version 18/19 Issue

Confluence v18-v19 had a **broken structure** where a massive code macro contained markdown content (not actual code):

```
<ac:structured-macro ac:name="code">
  <ac:plain-text-body>
    **Key Components:**
    - **Kong:** LoadBalancer service...
    - **external-dns:** Auto-creates Route53...

    ## Solution Design
    ...
    (hundreds of lines of markdown inside a code block!)
  </ac:plain-text-body>
</ac:structured-macro>
```

This caused:
- Gray code blocks in Confluence UI where there should be formatted text
- Markdown conversion errors (pandoc couldn't properly convert this mess)
- Single-line code blocks when they should be multi-line
- Missing syntax highlighting

### Markdown File Issues

The markdown file (`PANK-1485-Technical-Doc-Current.md`) had:
- Single-line code blocks: ` ``` DNS: Internet... ``` ` (wrong)
- No language tags on code blocks (no syntax highlighting)
- Malformed bash command blocks in Troubleshooting section

## What Was Fixed

### 1. Traffic Flow Section

**Before:**
```markdown
``` DNS: Internet → Cloudflare (uniphore.com) → Route53 (help.uniphore.com) → NLB IP HTTPS: Internet → NLB (Layer 4) → Kong (TLS termination) → Service ```
```

**After:**
```markdown
```
DNS: Internet → Cloudflare (uniphore.com) → Route53 (help.uniphore.com) → NLB IP
HTTPS: Internet → NLB (Layer 4) → Kong (TLS termination) → Service
```
```

### 2. Terraform Code Block

**Before:**
```markdown
``` resource "aws_route53_zone" "help_uniphore_com" { name = "help.uniphore.com" ... } ```
```

**After:**
```markdown
```hcl
resource "aws_route53_zone" "help_uniphore_com" {
  name = "help.uniphore.com"
  tags = {
    ManagedBy   = "terraform"
    Environment = "production"
  }
}

output "help_zone_nameservers" {
  value = aws_route53_zone.help_uniphore_com.name_servers
}
```
```

### 3. Troubleshooting Code Blocks

**Before:**
```markdown
``` kubectl describe certificate -n config-syncer help-uniphore-com kubectl logs -n cert-manager -l app=cert-manager kubectl get challenges -A ```
```

**After:**
```markdown
```bash
kubectl describe certificate -n config-syncer help-uniphore-com
kubectl logs -n cert-manager -l app=cert-manager
kubectl get challenges -A
```
```

### 4. Deployment Steps

**Before:**
```markdown
``` kubectl get certificate -n config-syncer help-uniphore-com kubectl get secret help-uniphore-com-cert -n platform -n kong ```
```

**After:**
```markdown
```bash
kubectl get certificate -n config-syncer help-uniphore-com
kubectl get secret help-uniphore-com-cert -n platform -n kong
```
```

## Result

- ✅ **Confluence v20** now has proper structure
- ✅ Code blocks only wrap actual code (not markdown content)
- ✅ All code blocks have language tags (bash, hcl, yaml)
- ✅ Multi-line formatting preserved
- ✅ Markdown file is clean and properly structured

## Bidirectional Sync Workflow

### Markdown → Confluence (Push)

```bash
source ~/.jira-helper/jira-helper.sh
replace_confluence_page 4220125196 /Users/jimsander/markdowns/PANK-1485-Technical-Doc-Current.md
```

This works well because `_markdown_to_wiki` properly converts:
- Code blocks → `{code:lang}...{code}` macros
- Headers → Confluence heading markup
- Links → Confluence links
- Lists → Confluence lists

### Confluence → Markdown (Pull)

**Problem:** Pandoc conversion from Confluence HTML creates artifacts.

**Options:**

#### Option A: Don't Pull (Recommended)
Keep markdown as source of truth. Only push to Confluence, never pull back.

**Workflow:**
1. Edit markdown file locally
2. Push to Confluence with `replace_confluence_page`
3. Verify in Confluence UI
4. Continue editing markdown (don't pull back)

#### Option B: Pull with Manual Cleanup
If you must pull from Confluence:

```bash
# Fetch Confluence page
source ~/.jira-helper/jira-helper.sh
_source_credentials

# Get current version
curl -s -u "${ATLASSIAN_USER}:${ATLASSIAN_DOCS}" \
  "https://${ATLASSIAN_SITE_URL}/wiki/rest/api/content/4220125196?expand=body.storage" \
  | jq -r '.body.storage.value' > /tmp/confluence-current.html

# Convert to markdown
pandoc /tmp/confluence-current.html -f html -t markdown -o /tmp/confluence-pulled.md

# Manual cleanup required:
# - Fix code block formatting
# - Remove HTML artifacts
# - Add language tags to code blocks
# - Fix escaped characters
```

**Not recommended** - too much manual work.

#### Option C: Improve Conversion Tool
Create a better Confluence → Markdown converter that:
- Handles code macros properly
- Preserves code block language tags
- Doesn't escape characters incorrectly
- Cleans HTML artifacts

This would be a jira-helper enhancement project.

## Best Practices

### 1. Markdown as Source of Truth

Always edit the markdown file, not Confluence UI.

**File:** `/Users/jimsander/markdowns/PANK-1485-Technical-Doc-Current.md`

### 2. Code Block Formatting

Always use proper multi-line code blocks with language tags:

```markdown
```bash
command line 1
command line 2
```

```yaml
key: value
nested:
  key: value
```

```hcl
resource "type" "name" {
  property = "value"
}
```
```

### 3. Version Control

Consider putting markdown files in git:

```bash
cd ~/markdowns
git init
git add PANK-1485*.md
git commit -m "Clean markdown structure for PANK-1485"
```

### 4. Testing Conversion

Before pushing large changes, test the conversion:

```bash
# Dry run - see what wiki markup will be generated
cat your-file.md | _markdown_to_wiki > /tmp/test-wiki.txt
less /tmp/test-wiki.txt
```

### 5. Confluence Placeholders

The markdown has placeholders for Confluence macros:

```markdown
[Confluence TOC Macro]
[Confluence Info Panel]
STATUS: POC PASSED [JIRA:PANK-1485]
[/Info Panel]
```

These are converted by `_markdown_to_wiki` to actual Confluence macros.

## Troubleshooting

### Code Blocks Not Rendering in Confluence

**Problem:** Code shows as inline text, not in a gray box

**Cause:** Missing backticks or wrong format

**Fix:** Ensure code blocks have proper markdown syntax:
```markdown
```lang
code here
```
```

### Syntax Highlighting Not Working

**Problem:** Code block renders but no syntax highlighting

**Cause:** Missing language tag

**Fix:** Add language after opening backticks:
```markdown
```bash  ← language tag
command
```
```

### HTML Artifacts After Pull

**Problem:** Pulled markdown has `{.external-link rel="nofollow"}` and similar

**Cause:** Pandoc converts HTML attributes to markdown attributes

**Fix:** Don't pull from Confluence. Use markdown as source of truth.

### Single-Line Code Blocks

**Problem:** Multi-line code compressed to single line

**Cause:** Missing newlines in markdown

**Fix:** Ensure code blocks have proper line breaks:

**Wrong:**
```markdown
``` command1 command2 command3 ```
```

**Right:**
```markdown
```
command1
command2
command3
```
```

## Version History

| Version | Date | Changes |
|---------|------|---------|
| v8 | Earlier | Initial design document |
| v18 | Previous | Added cluster-specific resources, broken code block structure |
| v19 | 2025-11-14 | Attempted fix (still had issues) |
| v20 | 2025-11-14 | **FIXED** - Proper code block structure, language tags added |

## Files

- **Main markdown:** `/Users/jimsander/markdowns/PANK-1485-Technical-Doc-Current.md`
- **Confluence page:** https://uniphore.atlassian.net/wiki/spaces/PlatEng/pages/4220125196/Help+Center+TLS+Solution+-+Technical
- **Version comparison:** `/Users/jimsander/markdowns/PANK-1485-Version-Comparison.md`
- **This guide:** `/Users/jimsander/markdowns/PANK-1485-Bidirectional-Sync-Guide.md`

## Summary

**Problem:** Bidirectional sync between Markdown and Confluence was creating formatting artifacts.

**Solution:**
1. Fixed markdown file to have proper code block formatting
2. Pushed clean markdown to Confluence (now v20)
3. Established "markdown as source of truth" workflow

**Workflow:** Edit markdown → Push to Confluence → Don't pull back

**Result:** Clean, properly formatted documentation in both formats.
