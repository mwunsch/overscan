#lang scribble/manual
@require[@for-label[ffi/unsafe/introspection
                    racket/base
                    ffi/unsafe]]

@title{GObject Introspection}

@defmodule[ffi/unsafe/introspection]

There's some introspection here.

@racketblock[
(define gst (introspection 'Gst))
]

@defproc[(introspection [wat list?])
         any?]{
 lol wut
}
