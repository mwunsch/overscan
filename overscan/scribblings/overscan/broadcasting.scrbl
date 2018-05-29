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

@defproc[(start [pipeline (is-a?/c pipeline%)]) thread?]{
}

@defproc[(on-air?) boolean?]{
}

@defproc[(stop [#:timeout timeout exact-nonnegative-integer? 5])
         state-change-return?]{
}

@defproc[(kill-broadcast) void?]{
}
