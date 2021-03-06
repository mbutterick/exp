#lang racket/base
(require racket/pretty
         racket/list
         racket/match
         racket/format
         csv-reading
         raart)

(define inventory
  (for/hash ([i (in-range 1 10)])
    (values (~a "P" i) 3)))
(define MAX-POSSIBLE (hash-count inventory))

(define (parse p)
  (match-define (list* head fac)
    (csv->list (make-csv-reader (open-input-file p))))
  (define opts
    (map (λ (x) (second (regexp-match #rx"\\[(.*?)\\]$" x)))
         (list-tail head 2)))
  (define all '())
  (vector
   (for/hash ([f (in-list fac)])
     (match-define (list* _ name prefs) f)
     (set! all (cons name all))
     (define these
       (sort
        (for/list ([p (in-list prefs)] [o (in-list opts)])
          (cons (min MAX-POSSIBLE (string->number p)) o))
        >= #:key car))
     (eprintf "~a => ~a\n" name these)
     (values name these))
   (reverse all)))

(define (go! v)
  (match-define (vector who->prefs all) v)
  ;; Problem Instance
  (struct state (name score seen assignment))

  (define best #f)
  (define best-sc -inf.0)
  (define past '())
  (define (try! #:keep? [keep? #f] name order)
    (define st
      (for/fold ([inv inventory]
                 [score 0] [assignment (hash)]
                 #:result
                 (state name score order assignment))
                ([who (in-list order)]
                 #:when (hash-has-key? who->prefs who))
        (define prefs (hash-ref who->prefs who))
        (match-define (cons this-score room-type)
          (for/or ([p (in-list prefs)])
            (and (< 0 (hash-ref inv (cdr p) 0))
                 p)))
        (values (hash-update inv room-type sub1)
                (+ score this-score)
                (hash-set assignment who (list room-type this-score)))))
    (define st-sc (state-score st))
    (cond
      [(< best-sc st-sc)
       (when best (set! past (cons best past)))
       (set! best st)
       (set! best-sc st-sc)
       (eprintf "New best! ~a ~v\n" name st-sc)]
      [keep?
       (set! past (cons st past))]))

  ;; Run problem
  (try! #:keep? #t "In Order" all)
  (define random-k 0)
  (define random-t
    (thread
     (λ ()
       (for/or ([i (in-naturals)])
         (try! (cons 'random i) (shuffle all))
         (set! random-k (add1 random-k))
         (thread-try-receive)))))
  (sleep (* 5 60))
  (thread-send random-t #t)
  (thread-wait random-t)
  (eprintf "Tried ~a random permutations\n" random-k)

  ;; Render Solution
  (define max-score (* MAX-POSSIBLE (length all)))
  (draw-here
   (vappend
    #:halign 'center
    (table #:inset-dw 1
           (text-rows
            (list* (list "Strategy" "Score" "%")
                   (for/list ([s (in-list (reverse (cons best past)))])
                     (match-define (state name score seen assignment) s)
                     (list name score (real->decimal-string (/ score max-score)))))))
    (table #:inset-dw 1
           (text-rows
            (list* (list "Who" "Project" "Score")
                   (for/list ([(k v) (in-hash (state-assignment best))])
                     (cons k v))))))))

(module+ main
  (go! (parse (build-path (find-system-path 'home-dir) "Downloads"
                          "preferences.csv"))))
