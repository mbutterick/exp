#lang racket/base
(require racket/system
         racket/port
         racket/path
         racket/list
         racket/file
         racket/match)

(define PLAN
  `(#[20 "Crunch"]
    #[ 5 "Rest"]
    #[20 "Crunch"]
    #[ 5 "Rest"]
    #[210 "Watch TV"]
    #[20 "Crunch"]
    #[ 5 "Rest"]
    #[20 "Crunch"]
    #[ 5 "Rest"]
    #[210 "Watch TV"]))

(define (snoc l x)
  (append l (list x)))

(define (system+ . s)
  (eprintf "~v\n" s)
  (apply system* s))

(define (audio-length p)
  (string->number
   (regexp-replace*
    #rx"\n"
    (with-output-to-string
      (λ ()
        (system+ (find-executable-path "soxi") "-D" p)))
    "")))

(define (audio-announce! s dest)
  (define dest-mono
    (build-path (path-only dest) "dest-mono.wav"))
  (system+ (find-executable-path "espeak")
           "-k20" "-w" dest-mono
           s)
  (system+ (find-executable-path "sox")
           dest-mono "-c" "2" "-r" "44100"
           dest)
  (delete-file dest-mono)
  dest)

(define (audio-clip! src start end dest)
  (system+ (find-executable-path "sox")
           src dest
           "trim" (number->string start)
           (number->string end))
  dest)

(define (combine! wavs dest)
  (when (empty? wavs)
    (error 'combine "Cannot combine no wavs"))
  (apply system+
         (find-executable-path "sox")
         (append wavs (list dest)))
  (for-each delete-file wavs)
  dest)

(define (wav->mp3! wav mp3)
  (system+ (find-executable-path "lame") "-S" wav mp3)
  (delete-file wav)
  mp3)

(define (output! PLAN dir)
  (define tmp-dir (build-path dir "tmp"))
  (make-directory* tmp-dir)
  (define (tmp-p p)
    (build-path tmp-dir (format "~a.wav" p)))

  (define music-dir (build-path dir "music"))
  (define music-files
    (sort (directory-list music-dir)
          string-ci<=?
          #:key path->string))
  (struct music-info (path len))
  (define music-infos
    (for/list ([mf (in-list music-files)])
      (define p (build-path music-dir mf))
      (define len (audio-length p))
      (music-info p len)))
  (define (music! dest start end)
    (define-values (now wavs)
      (for/fold ([then 0]
                 [wavs '()])
                ([mi (in-cycle music-infos)]
                 [i (in-naturals)]
                 #:break (< end then))
        (match-define (music-info p l) mi)
        (define now (+ then l))
        (define this-start (max start then))
        (define this-end (min end now))
        (define this-len (- this-end this-start))
        (define c-start (- this-start then))
        (define c-end (- this-end then))
        (when #f
          (eprintf "~v\n"
                   (vector 'music!
                           'start start 'end end
                           'then then 'now now
                           'tstart this-start 'tend this-end
                           'cstart c-start 'cend c-end
                           'len this-len)))
        (values now
                (if (< 0 this-len)
                    (snoc wavs
                          (audio-clip! p c-start c-end
                                       (tmp-p (format "~a-m" i))))
                    wavs))))
    (combine! wavs dest))

  (define-values
    (music-len wavs)
    (for/fold ([start-len 0]
               [wavs '()])
              ([p (in-list PLAN)]
               [i (in-naturals)])
      (match-define (vector this-len s) p)
      (define ann-wav
        (audio-announce! s (tmp-p (format "~a-ann" i))))
      (define end-len (+ start-len this-len))
      (define music-wav
        (music! (tmp-p (format "~a-mus" i)) start-len end-len))
      (define full-wav
        (combine! (list ann-wav music-wav) (tmp-p (format "~a-full" i))))
      (values end-len (snoc wavs full-wav))))

  (define dest-wav
    (combine! wavs (build-path dir "dest.wav")))
  (define dest-mp3
    (wav->mp3! dest-wav (build-path dir "dest.mp3")))

  dest-mp3)

(define (go! dir)
  (output! PLAN dir))

(module+ main
  (require racket/cmdline)
  (command-line #:program "workout-song"
                #:args (dir) (go! dir)))