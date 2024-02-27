---
title: LaTeX
weight: 10
---

# {{< katex style="font-size: 2em;" >}}
\LaTeX
{{< /katex >}}


## Creating PDF/A Documents

[pdfxdoc]: http://vesta.informatik.rwth-aachen.de/ftp/pub/mirror/ctan/macros/latex/contrib/pdfx/pdfx.pdf

This is a condensation of the information provided in the [`pdfx` package documentation][pdfxdoc]
and by [Peter Selinger](https://www.mathstat.dal.ca/~selinger/pdfa/):

> A PDF/A document is a special kind of PDF document that has been optimized for long-term archiving. [...]
> Some of the main features of PDF/A documents are:
>
> * **Self-containedness**: all resources that are required to reproduce the document's visual appearance, such as fonts, color spaces, etc., are embedded within the document itself. [...]
> * **Unicode mapping**: all of the document's content has been mapped to machine readable Unicode text. Such a mapping makes the document searchable, allows text to be copied and pasted, and allows text to be displayed in other forms (such as via a screen reader for the blind).
> * **Metadata**: PDF/A specifies a standardized format for including metadata, [...] which helps to ensure that the document can be found and correctly indexed by search engines, libraries, etc. 

It is best to produce the correct format from LaTeX sources directly and not to convert
an existing document with third-party tools. Otherwise information is lost in the process.

You'll need at least `pdfTeX` version 1.40.15. At the time of this writing my version was 1.40.21. Check the
version with `pdflatex --version`. And make sure you have at least version 1.5.8 of the `pdfx` package; it
is probably bundled already if you have a sufficiently recent distribution, however.

Add the necessary `pdfx` and `hyperref` packages to the document's preamble. It is best to place them
high up in the order – if possible directly below the `\documentclass`.
The `pdfx` package must be included first because it patches a few elements of the `hyperref` package for compliance.
In case you want to specify any options to the `hyperref` package use `\hypersetup`:

```latex
\documentclass[a4paper, 11pt, openright, twoside, ngerman]{report}
\usepackage[a-1b]{pdfx}
\usepackage{hyperref}
\hypersetup{hidelinks}
...
```

The document metadata is included from an `*.xmpdata` file. It must have the same basename as your main LaTeX
file. For example a `report.tex` needs a `report.xmpdata`. The format of this file and a list of possible
options is described in Section 2.2 of the [`pdfx` documentation][pdfxdoc]. Peter Sellinger also provides a
sample file to get going quickly.

A particularly useful option to provide this data file is by using a `{filecontents*}` environment before the
`\documentclass` at the very top of the main source file:

```latex
\begin{filecontents*}{\jobname.xmpdata}
  \Title{My Report}
  \Author{Anton Semjonov}
  \Language{de-DE}
  \Keywords{report\sep university}
  \Subject{A short description.}
\end{filecontents*}
\documentclass[...
```

If your section titles contain formulas you may need to fix the PDF outline links by providing an alternative
string with `\texorpdfstring{$<formula>$}{<string>}`. You can also use UTF-8 strings for that if your document uses
the appropriate input encoding:

```latex
\usepackage{inputenc}
\hypersetup{pdfencoding=unicode}
\inputencoding{utf8}
\makeatother
```

To test your document you can use `pdfinfo report.pdf`. It should output `PDF subtype: PDF/A-1b:2005` among
with your configured metadata.
