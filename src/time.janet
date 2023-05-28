
# Predefined common format strings
(defn- check-fmt [fmt]
  (case fmt
    :iso-8601 "%Y-%m-%dT%H:%M:%S%z"
    :rfc-3339 "%Y-%m-%dT%H:%M:%S%z"
    :rfc-2822 "%a, %d %b %Y %H:%M:%S %z"
    :w3c "%Y-%m-%dT%H:%M:%S%z"
    fmt))

(defn- with-tz [tz f]
  (default tz "UTC")
  (let [old-tz (os/getenv "TZ")]
    (os/setenv "TZ" tz)
    (defer
      (os/setenv "TZ" old-tz)
      (f))))




(defn time/now
  `Get current system time`
  []
  (os/clock :realtime))

(defn time/monotime []
  `Get current monotonic time`
  (os/clock :monotonic))

(defn time/cputime []
  `Get CPU time used by current process`
  (os/clock :cputime))


(defn time/to-datetime
  ``Convert a time to a datetime.`tz` is the timezone to use, default is the
  local time zone``
  [time &opt tz]
  (with-tz tz (fn []
    (os/date time true))))


(defn time/from-datetime
  ``Convert a datetime to a time. `tz` is the timezone to use, default is the
  local time zone``
  [dt &opt tz]
  (with-tz tz (fn []
    (os/mktime dt true))))


(def- timefmt-parser (peg/compile
  ~{:main (any :thing)
    :thing (+ :fmt :other)
    :fmt (replace (* "%" (<- :fmtchar)) ,(fn [c] (keyword c)))
    :other (<- (to "%"))
    :fmtchar (set "YmdHMSpIabcyABZc")
    }))


(defn make-time-parser [fmt]
  (let [dt @{}
        rule (peg/match timefmt-parser fmt)
        p ~{:main ,(tuple '* ;rule '(not 1))
            :Y (cmt (number 4) ,|(put dt :year $))
            :y (cmt (number 2) ,|(put dt :year (+ 2000 $)))
            :m (cmt (number 2) ,|(put dt :month (dec $)))
            :d (cmt (number 2) ,|(put dt :month-day (dec $)))
            :H (cmt (number 2) ,|(put dt :hours $))
            :I (cmt (number 2) ,|(put dt :hours $))
            :M (cmt (number 2) ,|(put dt :minutes $))
            :S (cmt (number 2) ,|(put dt :seconds $))
            :p (+ "AM" :PM)
            :PM (cmt "PM" ,|(update dt :hours (fn [h] (+ h 12))))
            }]
    (fn [ts]
      (peg/match p ts)
      dt)))


(def parser-cache @{}) # TODO: thread safe?

(defn time/parse
  ``parse a time in the given format. The format string is a subset of the C89
  strftime(3) format:
  - %Y: year, 4 digits
  - %y: year, 2 digits, 2000 is added if the year is less than 70
  - %m: month, 2 digits, 01-12
  - %d: day, 2 digits, 01-31
  - %H: hour, 2 digits, 00-23
  - %I: hour, 2 digits, 01-12
  - %M: minute, 2 digits, 00-59
  - %S: second, 2 digits, 00-59
  - %p: AM/PM
  or one of the predefined formats:
  - :iso-8601
  - :rfc-3339
  - :rfc-2822
  - :w3c
  The time zone is optional, default is the local time zone.``
  # TODO
  #- %z: time zone offset, +0800
  #- %Z: time zone name, UTC
  [fmt ts &opt tz]
  (with-tz tz (fn []
    (def fmt (check-fmt fmt))
    (def parser
      (if (parser-cache fmt)
        (parser-cache fmt)
        (do
          (def parser (make-time-parser fmt))
          (put parser-cache fmt parser)
          parser)))

      (def dt (parser ts))
      (os/mktime dt true))))


(defn time/format 
  ``Format the given time to ASCII string. The format string is C89 strftime(3)
  format, or one of the predefined formats:
   - :iso-8601
   - :rfc-3339
   - :rfc-2822
   - :w3c
  The time zone is optional, default is the local time zone.``
  [time &opt fmt tz]
  (default fmt :rfc-2822)
  (with-tz tz (fn []
    (os/strftime (check-fmt fmt) time true))))


