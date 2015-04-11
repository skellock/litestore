import json, db_sqlite, strutils, pegs, asyncdispatch, asynchttpserver2, times, logging, math, sqlite3
import types, queries, contenttypes

proc dbg*(args: varargs[string, `$`]) =
  if logging.level <= lvlDebug:
    echo "DEBUG - "&args.join(" ")

proc dbQuote*(s: string): string =
  result = "'"
  for c in items(s):
    if c == '\'': add(result, "''")
    else: add(result, c)
  add(result, '\'')

proc currentTime*(): string =
  return getTime().getGMTime().format("yyyy-MM-dd'T'hh:mm:ss'Z'")

proc selectDocumentsByTags(tags: string): string =
  var select_tagged = "SELECT document_id FROM tags WHERE tag_id = '"
  result = ""
  for tag in tags.split(','):
    if not tag.match(PEG_TAG):
      raise newException(EInvalidTag, "Invalid tag '$1'" % tag)
    result = result & "AND id IN (" & select_tagged & tag & "') "
   
proc prepareSelectDocumentsQuery*(options: var QueryOptions): string =
  result = "SELECT "
  if options.search.len > 0:
    if options.select[0] != "COUNT(id)":
      options.select.add("snippet(searchcontents) AS highlight")
      options.select.add("rank(matchinfo(searchcontents, 'pcxnal'), 1.20, 0.75, 5.0, 0.5) AS rank")
      options.orderby = "rank DESC"
    result = result & options.select.join(", ")
    result = result & " FROM documents, searchcontents "
    result = result & "WHERE documents.id = searchcontents.document_id "
  else:
    result = result & options.select.join(", ")
    result = result & " FROM documents WHERE 1=1 "
  if options.single:
    result = result & "AND id = ?"
  if options.tags.len > 0:
    result = result & options.tags.selectDocumentsByTags()
  if options.search.len > 0:
    result = result & "AND searchcontents MATCH '" & options.search.replace("'", "''") & "' "
  if options.orderby.len > 0 and options.select[0] != "COUNT(id)":
    result = result & "ORDER BY " & options.orderby & " " 
  if options.limit > 0:
    result = result & "LIMIT " & $options.limit & " "
    if options.offset > 0:
      result = result & "OFFSET " & $options.offset & " "
  dbg(result)

proc prepareSelectTagsQuery*(options: QueryOptions): string =
  result = "SELECT tag_id, COUNT(document_ID) "
  result = result & "FROM tags "
  if options.single:
    result = result & "WHERE tag_id = ?"
  result = result & "GROUP BY tag_id"
  if options.orderby.len > 0:
    result = result & "ORDER BY " & options.orderby&" " 
  if options.limit > 0:
    result = result & "LIMIT " & $options.limit & " "
  dbg(result)

proc prepareJsonDocument*(store:Datastore, doc: TRow, cols:seq[string]): JsonNode =
  var raw_tags = store.db.getAllRows(SQL_SELECT_DOCUMENT_TAGS, doc[0])
  var tags = newSeq[JsonNode](0)
  for tag in raw_tags:
    tags.add(%($(tag[0])))
  if doc.len == 1:
    # COUNT(id)
    return %(doc[0].parseInt)
  var res = newSeq[tuple[key: string, val: JsonNode]](0)
  var count = 0
  for s in cols:
    var key = s
    if s.contains(" "):
      let chunks = s.split(" ")
      key = chunks[chunks.len-1]
    res.add((key, %doc[count]))
    count.inc
  res.add(("tags", %tags))
  return %res

proc toPlainText*(s: string): string =
  let subs = @[
    (pattern: peg"""\<\/?[^<>]+\>""", repl: ""),
    (pattern: peg"""{[_*/+!=?%$^-]+} {(!$1 .)+} $1""", repl: "$2")
  ]
  return s.parallelReplace(subs)

proc checkIfBinary*(binary:int, contenttype:string): int =
  if binary == -1 and contenttype.isBinary:
    return 1
  else:
    return binary

proc addDocumentSystemTags*(store: Datastore, docid, contenttype: string) =
  var splittype = contenttype.split("/")
  var tags = newSeq[string](0)
  tags.add "$type:"&splittype[0]
  tags.add "$subtype:"&splittype[1]
  var binary = checkIfBinary(-1, contenttype)
  if binary == 1:
    tags.add "$format:binary"
  else:
    tags.add "$format:text"
  for tag in tags:
    store.db.exec(SQL_INSERT_TAG, tag, docid)

proc destroyDocumentSystemTags*(store: Datastore, docid) = 
  store.db.exec(SQL_DELETE_DOCUMENT_SYSTEM_TAGS, docid)

proc fail*(code, msg) =
  stderr.writeln(msg)
  quit(code)

proc resError*(code: HttpCode, message: string, trace = ""): Response =
  warn(message)
  if trace.len > 0:
    dbg(trace)
  result.code = code
  result.content = """{"error":"$1"}""" % message
  result.headers = ctJsonHeader()

proc resDocumentNotFound*(id): Response =
  resError(Http404, "Document '$1' not found." % id)

#  Created by Joshua Wilson on 27/05/14.
#  Copyright (c) 2014 Joshua Wilson. All rights reserved.
#  https://github.com/neozenith/sqlite-okapi-bm25
#
# This is an extension to the work of "Radford 'rads' Smith"
# found at: https://github.com/rads/sqlite-okapi-bm25
# which is covered by the MIT License
# http://opensource.org/licenses/MIT
# the following code shall also be covered by the same MIT License
proc okapi_bm25f_kb*(pCtx: Pcontext, nVal: int32, apVal: PValueArg) {.cdecl.} =
  var matchinfo = cast[ptr uarray[int32]](value_blob(apVal[0]))
  # Setting the default values and ignoring argument based inputs so the extra
  # arguments can be the column weights instead.
  if nVal < 2:
    pCtx.result_error("wrong number of arguments to function okapi_bm25_kb(), expected k1 parameter", -1)
  if nVal < 3: 
    pCtx.result_error("wrong number of arguments to function okapi_bm25_kb(), expected b parameter", -1);
  let K1 = value_double(apVal[1]) # 1.2
  let B = value_double(apVal[2])  # 0.75
  # For a good explanation fo the maths and how to choose these variables
  # http://stackoverflow.com/a/23161886/622276
  # NOTE: the rearranged order of parameters to match the order presented on
  # SQLite3 FTS3 documentation 'pcxnals' (http://www.sqlite.org/fts3.html#matchinfo)
  let P_OFFSET = 0
  let C_OFFSET = 1
  let X_OFFSET = 2
  let termCount = matchinfo[P_OFFSET].int32
  let colCount = matchinfo[C_OFFSET].int32
  let N_OFFSET = X_OFFSET + 3*termCount*colCount
  let A_OFFSET = N_OFFSET + 1
  let L_OFFSET = A_OFFSET + colCount
  let totalDocs = matchinfo[N_OFFSET].float
  var avgLength:float = 0.0 
  var docLength:float = 0.0 
  for col in 0..colCount-1:
    avgLength = avgLength + matchinfo[A_OFFSET + col].float
    docLength = docLength + matchinfo[L_OFFSET + col].float
  var epsilon = 1.0 / (totalDocs*avgLength)
  var sum = 0.0;
  for i in 0..termCount-1:
    for col in 0..colCount-1:
      let currentX = X_OFFSET + (3 *  col * (i + 1))
      let termFrequency = matchinfo[currentX].float
      let docsWithTerm = matchinfo[currentX + 2].float
      var idf: float = ln((totalDocs - docsWithTerm + 0.5) / (docsWithTerm + 0.5))
      # "...terms appearing in more than half of the corpus will provide negative contributions to the final document score."
      # http://en.wikipedia.org/wiki/Okapi_BM25
      idf = if idf < 0: epsilon else: idf
      var rightSide: float = (termFrequency * (K1 + 1)) / (termFrequency + (K1 * (1 - B + (B * (docLength / avgLength)))))
      rightSide = rightSide+1.0
      # To comply with BM25+ that solves a lower bounding issue where large documents that match are unfairly scored as
      # having similar relevancy as short documents that do not contain as many terms
      # Yuanhua Lv and ChengXiang Zhai. 'Lower-bounding term frequency normalization.' In Proceedings of CIKM'2011, pages 7-16.
      # http://sifaka.cs.uiuc.edu/~ylv2/pub/cikm11-lowerbound.pdf
      let weight:float = if nVal > col+3: value_double(apVal[col+3]) else: 1.0
      sum = sum + (idf * rightSide) * weight
  pCtx.result_double(sum)
