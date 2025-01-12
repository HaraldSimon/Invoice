// InvoiceXML
//
// Author: Harald Simon (https://github.com/HaraldSimon/Invoice)
//
// Functions and procedures for handling CrossIndustryInvoice and XMLInvoice

unit InvoiceXML;

interface

uses
  System.Types,
  System.Classes,
  System.SysUtils,
  System.Generics.Collections,
  Xml.xmldom,
  Xml.omnixmldom,
  Xml.Internal.OmniXML,
  Xml.XMLDoc,
  Xml.XMLIntf,
  XMLDataBindingUtils,
  CrossIndustryInvoice,
  UBLInvoice;


function CrossIndustryInvoiceGet(IDoc: IXMLDocument): IXMLCrossIndustryInvoiceType;
function CrossIndustryInvoiceLoad(const sFilename: string): IXMLCrossIndustryInvoiceType;
function CrossIndustryInvoiceNew: IXMLCrossIndustryInvoiceType;
procedure CrossIndustryInvoiceSaveToStream(ICII : IXMLCrossIndustryInvoiceType; obStream : TStream);

function XMLInvoiceGet(IDocument: IXMLDocument): IXMLInvoice;
function XMLInvoiceLoad(const sFilename: String): IXMLInvoice;
function XMLInvoiceNew : IXMLInvoice;
procedure XMLInvoiceSaveToStream(IUBL: IXMLInvoice; obStream : TStream);


implementation

type
  XMLNamespaceList = TDictionary<String, String>;

  TNamespaceEntry = record
    sURI : String;
    sID  : String;
  end;

const
  atNamespaces_CrossIndustryInvoice : Array[0..4] of TNamespaceEntry =
  (
    ( sURI: 'http://www.w3.org/2001/XMLSchema-instance';                                          sID: 'xsi' ),
    ( sURI: 'urn:un:unece:uncefact:data:standard:QualifiedDataType:100';                          sID: 'qdt' ),
    ( sURI: 'urn:un:unece:uncefact:data:standard:UnqualifiedDataType:100';                        sID: 'udt' ),
    ( sURI: 'urn:un:unece:uncefact:data:standard:CrossIndustryInvoice:100';                       sID: 'rsm' ),
    ( sURI: 'urn:un:unece:uncefact:data:standard:ReusableAggregateBusinessInformationEntity:100'; sID: 'ram' )
  );

  NAMESPACE_CrossIndustryInvoice = 'urn:un:unece:uncefact:data:standard:CrossIndustryInvoice:100';


  atNamespaces_XMLinvoice : Array[0..3] of TNamespaceEntry =
  (
    ( sURI: 'urn:oasis:names:specification:ubl:schema:xsd:Invoice-2';                             sID: 'ubl' ),
    ( sURI: 'urn:oasis:names:specification:ubl:schema:xsd:CommonAggregateComponents-2';           sID: 'cac' ),
    ( sURI: 'urn:oasis:names:specification:ubl:schema:xsd:CommonBasicComponents-2';               sID: 'cbc' ),
    ( sURI: 'http://www.w3.org/2001/XMLSchema-instance';                                          sID: 'xsi' )
  );

  NAMESPACE_XMLInvoice = 'urn:oasis:names:specification:ubl:schema:xsd:Invoice-2';


////////////////////////////////////////////////////////////////////////////////
// Helper functions
////////////////////////////////////////////////////////////////////////////////

// XMLSaveToStream
// Saves an XML document as the validators expect it to be saved:
// - fixed namespaces with namespace abbreviation definition in the first node, no more thereafter
// - all nodes with namespace abbreviation
// - no standard namespaces
// - only real value attributes in one line, the rest wrapped with LF
// - empty nodes have at least one LF inside, otherwise portinvoice.com complains

procedure XMLSaveToStream(Document : IXMLDocument; obStream : TStream; atNamespaces : Array of TNamespaceEntry; sSchemaLocation : String);

  function PrefixGet(const sURI : String; out sPrefix : String) : Boolean;
  var
    i : Integer;
  begin
    for i := Low(atNamespaces) to High(atNamespaces) do
    begin
      if SameText(sURI, atNamespaces[i].sURI) then
      begin
        sPrefix:=atNamespaces[i].sID;
        Exit(true);
      end;
    end;

    sPrefix:='';
    Exit(false);
  end;

  function InNamespaces(const sID : String) : Boolean;
  var
    i : Integer;
  begin
    for i := Low(atNamespaces) to High(atNamespaces) do
    begin
      if (sID = atNamespaces[i].sID) then
        Exit(true);
    end;

    Exit(false);
  end;

  procedure Prolog;
  const
    sProlog : AnsiString ='<?xml version="1.0" encoding="UTF-8"?>'#10;
  begin
    obStream.Write(PAnsiChar(sProlog)^, Length(sProlog));
  end;

  procedure Write(Node : IXMLNode; oNamespaces : Boolean);
  var
    sPrefix : String;
    abName, abAttributname, abWert : TBytes;
    i : Integer;
  begin
    if PrefixGet(Node.NamespaceURI, sPrefix) then
      abName:=TEncoding.UTF8.GetBytes(sPrefix +':'+ Node.LocalName)
    else
      abName:=TEncoding.UTF8.GetBytes(Node.LocalName);

    obStream.Write(PAnsiChar('<')^, 1);
    obStream.Write(abName, 0, Length(abName));

    if Assigned(Node.AttributeNodes) and (Node.AttributeNodes.Count > 0) then
    begin
      for i := 0 to Node.AttributeNodes.Count-1 do
      begin
        if (Node.AttributeNodes[i].NodeName = 'xmlns') then
          continue;

        if (Node.AttributeNodes[i].Prefix = 'xmlns') and InNamespaces(Node.AttributeNodes[i].LocalName) then // Skip namespaces by loaded documents if necessary, if in the global list
          continue;

        if oNamespaces and (sSchemaLocation <> '') and (Node.AttributeNodes[i].NodeName = 'xsi:schemaLocation') then
          continue;

        abAttributname:=TEncoding.UTF8.GetBytes(Node.AttributeNodes[i].NodeName);
        abWert:=TEncoding.UTF8.GetBytes(EncodeText(Node.AttributeNodes[i].Text));

        obStream.Write(PAnsiChar(' ')^, 1);
        obStream.Write(abAttributname, 0, Length(abAttributname));
        obStream.Write(PAnsiChar('="')^, 2);
        obStream.Write(abWert, 0, Length(abWert));
        obStream.Write(PAnsiChar('"')^, 1);
      end;
    end;

    if oNamespaces then
    begin
      for i := Low(atNamespaces) to High(atNamespaces) do
      begin
        abAttributname:=TEncoding.UTF8.GetBytes('xmlns:'+atNamespaces[i].sID);
        abWert:=TEncoding.UTF8.GetBytes(atNamespaces[i].sURI);

        obStream.Write(PAnsiChar(' ')^, 1);
        obStream.Write(abAttributname, 0, Length(abAttributname));
        obStream.Write(PAnsiChar('="')^, 2);
        obStream.Write(abWert, 0, Length(abWert));
        obStream.Write(PAnsiChar('"')^, 1);
      end;

      if (sSchemaLocation <> '') then
      begin
        obStream.Write(PAnsiChar(' xsi:schemaLocation="')^, 21);
        abWert:=TEncoding.UTF8.GetBytes(sSchemaLocation);
        obStream.Write(abWert, 0, Length(abWert));
        obStream.Write(PAnsiChar('"')^, 1);
      end;
    end;

    obStream.Write(PAnsiChar('>')^, 1);                                             // always close nodes without end marker, as empty nodes are flagged by portinvoice.com

    if Node.IsTextElement then
    begin
      if (Node.Text <> '') then
      begin
        abWert:=TEncoding.UTF8.GetBytes(EncodeText(Node.Text));
        obStream.Write(abWert, 0, Length(abWert));
      end
      else
        obStream.Write(PAnsiChar(#10)^, 1);                                         // avoid empty nodes, otherwise portinvoice.com will complain
    end
    else if Node.HasChildNodes then
    begin
      obStream.Write(PAnsiChar(#10)^, 1);

      for i := 0 to Node.ChildNodes.Count-1 do
      begin
        Write(Node.ChildNodes[i], false);
      end;
    end
    else
    begin
      obStream.Write(PAnsiChar(#10)^, 1);                                           // avoid empty nodes, otherwise portinvoice.com will complain
    end;

    obStream.Write(PAnsiChar('</')^, 2);
    obStream.Write(abName, 0, Length(abName));
    obStream.Write(PAnsiChar('>')^, 1);
    obStream.Write(PAnsiChar(#10)^, 1);
  end;

begin
  Prolog;

  // main node is #document, zeroth childnode xml Prolog, first childnode contains the actual main node

  if (Document.ChildNodes.Count = 2) then
    Write(Document.ChildNodes[1], true);
end;


////////////////////////////////////////////////////////////////////////////////
// CrossIndustryInvoice (CII)
////////////////////////////////////////////////////////////////////////////////


// CrossIndustryInvoiceGet

function CrossIndustryInvoiceGet(IDoc: IXMLDocument): IXMLCrossIndustryInvoiceType;
begin
  Result := IDoc.GetDocBinding('CrossIndustryInvoice', TXMLCrossIndustryInvoiceType, NAMESPACE_CrossIndustryInvoice) as IXMLCrossIndustryInvoiceType;
end;

// CrossIndustryInvoiceLoad

function CrossIndustryInvoiceLoad(const sFilename: string): IXMLCrossIndustryInvoiceType;
begin
  Result := CrossIndustryInvoiceGet(LoadXMLDocument(sFilename));
end;

// CrossIndustryInvoiceNew

function CrossIndustryInvoiceNew: IXMLCrossIndustryInvoiceType;
begin
  Result := CrossIndustryInvoiceGet(NewXMLDocument);
end;

// CrossIndustryInvoiceSaveToStream

procedure CrossIndustryInvoiceSaveToStream(ICII : IXMLCrossIndustryInvoiceType; obStream : TStream);
begin
  XMLSaveToStream(ICII.OwnerDocument, obStream, atNamespaces_CrossIndustryInvoice, '');
end;


////////////////////////////////////////////////////////////////////////////////
// XMLinvoice (UBL)
////////////////////////////////////////////////////////////////////////////////


// XMLInvoiceGet

function XMLInvoiceGet(IDocument: IXMLDocument): IXMLInvoice;
begin
  Result := IDocument.GetDocBinding('Invoice', TXMLinvoice, NAMESPACE_XMLInvoice) as IXMLInvoice;
end;

// XMLInvoiceLoad

function XMLInvoiceLoad(const sFilename: String): IXMLInvoice;
begin
  Result := XMLInvoiceGet(LoadXMLDocument(sFilename));
end;

// XMLInvoiceNew

function XMLInvoiceNew : IXMLInvoice;
begin
  Result := XMLInvoiceGet(NewXMLDocument);
end;

// XMLInvoiceSaveToStream

procedure XMLInvoiceSaveToStream(IUBL: IXMLInvoice; obStream : TStream);
begin
  XMLSaveToStream(IUBL.OwnerDocument, obStream, atNamespaces_XMLinvoice, 'urn:oasis:names:specification:ubl:schema:xsd:Invoice-2 http://docs.oasis-open.org/ubl/os-UBL-2.2/xsd/maindoc/UBL-Invoice-2.2.xsd');
end;

////////////////////////////////////////////////////////////////////////////////


initialization

  DefaultDOMVendor := sOmniXmlVendor;

end.
