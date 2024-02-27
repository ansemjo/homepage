---
title: Software
weight: 10
---

# Software

A few links to useful software.

## Collaboration

A collection of nice software that can be used for collaborative tasks, preferrably self-hosted.

| Name                                         | Description                                                                 | self-hosted |
| :------------------------------------------- | --------------------------------------------------------------------------- | ----------- |
| [Airtable](https://airtable.com/)            | Cloud-hosted Database with a beautiful UI and API integration               | no          |
| [CodiMD](https://github.com/hackmdio/codimd) | Free fork of HackMD, realtime collaborative text editor similar to etherpad | yes         |

## Archival

An overview of archival software for different purposes.

### E-Mail

| Name                                                      | Type        | Notes                                                                                           |
| :-------------------------------------------------------- | ----------- | ----------------------------------------------------------------------------------------------- |
| [ansemjo/imapfetch](https://github.com/ansemjo/imapfetch) | Python      | fetches from IMAP, config via `ini`, archived in maildir for `mutt`                             |
| [raymii/NoPriv](https://raymii.org/s/tags/nopriv.html)    | Python      | open formats, no search, combination with `imapbox` and `calaca` possible, exports to HTML tree |
| [mailpiler](http://www.mailpiler.org/)                    | PHP         | many dependencies, only accepts via SMTP receiver                                               |
| [Mailstore](https://www.mailstore.com/)                   | Windows App | requires Windows, no scheduling in the free Home version                                        |
| [Mailarchiva](https://www.mailarchiva.com/)               | Java        | werid licensing model, cumbersome installation                                                  |

### Documents

| Name       | Server              | Client                | OCR       | Notes                                                                                                  |
| :--------- |:-------------------:|:---------------------:|:---------:| ------------------------------------------------------------------------------------------------------ |
| Docspell   | Docker              | Web                   | yes       | https://github.com/eikek/docspell
| mayanEDMS  | Docker              | Web                   | yes       | not sure why I initially dismissed this .. beautiful, has OCR, easily installed with docker-compose .. |
| ecodms     | Debian / Docker     | Web / Windows / Linux | yes       | not very pretty; simple installation                                                                   |
| logicalDoc | Docker              | Web                   | not in CE | nice feature set and relatively easy to set up; lacks OCR in community edition                         |
| ambar      | huge docker-compose | Web                   | yes       | ONLY for searching; good for temporary projects                                                        |
| seeddms    | LAMP stack          | Web                   | ?         | rather simple, fewer professional features                                                             |
| nuxeo      | Debian / Docker     | Web                   | no        | very beautiful; resource intensive and not very intuitive / usable for smaller deployments             |
| agorum     | ?                   | Web                   | yes       | not successfully demo-ed yet; looks promising though                                                   |
