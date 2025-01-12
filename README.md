# Invoice
Classes, functions and procedures for handling CrossIndustryInvoice and XMLInvoice

CrossIndustryInvoice.pas and UBLInvoice.pas were created with [HaraldSimon/x2xmldatabinding](https://github.com/HaraldSimon/x2xmldatabinding).

XMLDataBindingUtils.pas ist taken from [MvRens/x2xmldatabinding](https://github.com/MvRens/x2xmldatabinding).

InvoiceXML.pas contains functions and procedures for handling IXMLCrossIndustryInvoiceType and IXMLInvoice.

## Example CII

```
  var ICII : IXMLCrossIndustryInvoiceType;

  try
    ICII:=CrossIndustryInvoiceNew;

    // BT-23

    ICII.ExchangedDocumentContext.BusinessProcessSpecifiedDocumentContextParameter.Add.ID.Text:='urn:fdc:peppol.eu:2017:poacc:billing:01:1.0';

    // BT-24

    ICII.ExchangedDocumentContext.GuidelineSpecifiedDocumentContextParameter.Add.ID.Text:='urn:cen.eu:en16931:2017#compliant#urn:xeinkauf.de:kosit:xrechnung_3.0';

    // BT-1

    ICII.ExchangedDocument.ID.Text:='2025-0001';

    // BT-3

    ICII.ExchangedDocument.TypeCode.Text:='380';

	...

    CrossIndustryInvoiceSaveToStream(ICII, obStream);
  except
  end;

  ICII:=nil;
```

## Example UBL

```
  var IUBL : IXMLInvoice;

  try
    IUBL:=XMLInvoiceNew;

    // BT-24

    IUBL.CustomizationID.Text:='urn:cen.eu:en16931:2017#compliant#urn:xeinkauf.de:kosit:xrechnung_3.0';

    // BT-23

    IUBL.ProfileID.Text:='urn:fdc:peppol.eu:2017:poacc:billing:01:1.0';;

    // BT-1

    IUBL.ID.Text:='2025-0001';

    // BT-3

    IUBL.InvoiceTypeCode.Text:='380';

	...

    XMLInvoiceSaveToStream(IUBL, obStream);
  except
  end;

  IUBL:=nil;
```
