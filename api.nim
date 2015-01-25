import asynchttpserver, asyncdispatch, strutils 
from strtabs import StringTableRef, newStringTable
import types, core

proc resError*(code: HttpCode, message: string): Response =
  result.code = code
  result.content = """{"code": $1, "message":"$2"}""" % [($code)[0..2], message]
  result.headers = CT_JSON.newStringTable

proc resDocumentNotFound*(id): Response =
  resError(Http404, "Document '$1' not found." % id)

proc getRawDocument*(LS: LiteStore, id: string, options = newQueryOptions()): Response =
  let doc = LS.store.retrieveRawDocument(id, options)
  result.headers = CT_JSON.newStringTable
  if doc == "":
    result = resDocumentNotFound(id)
  else:
    result.content = doc
    result.code = Http200

proc getDocument*(LS: LiteStore, id: string, options = newQueryOptions()): Response =
  let doc = LS.store.retrieveDocument(id, options)
  if doc.data == "":
    result = resDocumentNotFound(id)
  else:
    result.headers = doc.contenttype.ctHeader
    result.content = doc.data
    result.code = Http200

proc getRawDocuments*(LS: LiteStore, options = newQueryOptions()): Response =
  let docs = LS.store.retrieveRawDocuments(options) # TODO Implement query options
  if docs.len == 0:
    result = resError(Http404, "No documents found.")
  else:
    result.headers = ctJsonHeader()
    result.content = docs
    result.code = Http200
