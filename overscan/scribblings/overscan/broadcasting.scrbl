#lang scribble/manual

@title[#:tag "broadcasting"]{Broadcasting}

@defproc[(make-broadcast [video-source (is-a?/c element%)]
                         [audio-source (is-a?/c element%)]
                         [flv-sink (is-a?/c element%)]
                         [#:name name (or/c string? false/c)]
                         [#:preview video-preview (is-a?/c element%)]
                         [#:monitor audio-monitor (is-a?/c element%)]
                         [#:h264-encoder h264-encoder (is-a?/c element%)]
                         [#:aac-encoder aac-encoder (is-a?/c element%)])
                         (or/c (is-a?/c pipeline%) #f)]{
}
