# This file documents substantial changes to the format of data files

2017-08-15

To reduce data bloat, we will no longer be including 'lang__xx' data where that
is identical to 'lang__en'.

This currently only applies to Areas, but will be applied to other
collections over time.

Other language fallback chains may be implemented later.

2016-12-12

Information on 'sources' is now provided on `Membership` rather than
`Person` records.

2016-09-23

* Wikidata references are no longer at the top level of legislative
period `Event`s, but now correctly included as `identifiers`

2016-07-26

* The `Organization` for each legislature now has a unique ID, rather
than being simply "legislature" everywhere.

2016-05-29

* Some Election data is now available as Popolo `Event`s.

2016-01-09

* Twitter handles are now standardised into a bare handle in
`contact_details` and a full URL in `links`

2015-11-23

* `countries.json` now points at the `names.csv` file for each
legislature
