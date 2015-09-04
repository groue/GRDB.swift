The Design of GRDB.swift
========================

More than caveats or defects, there are a few glitches, or surprises in the GRDB.swift API. We try to explain them here.

- Why can't NSObject adopt DatabaseValueConvertible, so that native NSDate, NSData, UIImage could be used as query arguments, or fetched values?
- Why is RowModel a class, when protocols are all the rage?

TO BE CONTINUED
