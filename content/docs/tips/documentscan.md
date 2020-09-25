# Document Scanning

For my document management workflow I have settled on an Android scanner app
and optical character recognition on the commandline for now.

## Scanbot

The scanner app is [Scanbot](https://scanbot.io/). It is touted as the preferred
document scanner app in various articles and has a couple of advantages compared
to its competitors. Among them are a nice and clean interface which is important
for a quick workflow and automatic uploading to a cloud storage of your choice,
including local network SFTP servers. The Pro version is required for this but
it is not too expensive.

## OCRmyPDF

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
