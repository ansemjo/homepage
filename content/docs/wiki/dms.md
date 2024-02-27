---
title: Documents
weight: 10
---

# Document Management


## Document Management Systems

I've recently found [Docspell](https://github.com/eikek/docspell) which I find to be
a very nice DMS that can easily be hosted at home. I'll look into it in the future.
There's some more listed under [Software]({{< relref "software.md#documents" >}}).


## Scanning Documents

For my document management workflow I have settled on an Android scanner app
and optical character recognition on the commandline for now.

### Scanbot

The scanner app I use is [SwiftScan](https://swiftscan.app/) (using the
[Scanbot SDK](https://scanbot.io/)). It is touted as the preferred
document scanner app in various articles and has a couple of advantages compared
to its competitors. Among them are a nice and clean interface which is important
for a quick workflow and automatic uploading to a cloud storage of your choice,
including local network SFTP servers. The Pro version is required for this but
it is not too expensive.

### `simple-scan` with Samsung

Oh my god. I've struggled with this for *soo* long. I have a Samsung M2070 and
for the longest time I just could not scan from Linux. None of the answers suggesting
edits to various files in `/etc/sane.d/` worked. `simple-scan` would *at best* talk to the
scanner but then hiccup on unexpected `\x00`s (I don't remember the exact error, it
was frustrating).

In the end it turns out you just need to have the `samsung-unified-driver` installed and
start `simple-scan` by explicitly pointing it to your scanner with this weird syntax:

    simple-scan "smfp:net;printer.lan"

### OCRmyPDF

OCR is performed on a Linux computer with [`ocrmypdf`](https://ocrmypdf.readthedocs.io/en/latest/installation.html).
This has the advantage of using a beefier CPU to do the OCR and save my smartphone
battery. It also produces consistently nice results because the tesseract engine
it uses is pretty awesome.

On many distributions it is available as a package in the repositories. On CentOS 7
you can install it and all its dependencies with (Python 3.6 + `pip` required):

    pip install ocrmypdf
    yum install -y ghostscript qpdf tesseract tesseract-langpack-deu unpaper pngquant

Additionally I use the following bash alias to easily perform OCR on documents in-place:

    ocr () { 
      file=$1;
      shift 1;
      [[ -z $file ]] && { 
        printf 'perform ocr on pdfs with ocrmypdf\nusage: %s <path/to/pdf> [<extra args>]\n' "$0" 1>&2;
        exit 1
      };
      ocrmypdf -cd "$@" "$file" "$file"
    }

## Indexing

After some hiccups, the GNOME tracker works pretty nicely for full-text indexing of
my scanned documents. If everything was indexed correctly, you can search for your
documents in the GNOME Documents program or enable full-text search in Nautilus by
pressing on the magnifying glass icon.

## Signing

I would like to add cryptographic signatures to my PDFs but there appear to be no Linux
programs capable of adding such signatures from an X.509 certificate. Regardless, my default
viewer evince would not display such signatures. If I have important documents I should
thereforre resort to using detached GPG signatures or regularly signing a sha256sum file.


