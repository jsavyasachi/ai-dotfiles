(ns clojars-stats
  "Pull Clojars download stats for the net.clojars.savya artifacts and surface the
   only signal that matters: a version pulling ahead of its siblings (the fingerprint
   of a real dependent, vs. the uniform per-version baseline a crawler/cljdoc leaves).

   Data sources:
   - API   https://clojars.org/api/artifacts/<group>/<artifact>  (lifetime totals + per-version)
   - Feed  https://clojars.org/stats/downloads-YYYYMMDD.edn       (daily CDN log, 302 -> S3)"
  (:require [babashka.http-client :as http]
            [cheshire.core :as json]
            [clojure.edn :as edn]
            [clojure.string :as str]))

(def group "net.clojars.savya")

(def artifacts
  ["hier-set" "lein-shell" "lein-environ" "beckon" "beckon-ffm" "inet.data"
   "environ" "digest" "clj-xchart" "jackdaw" "cljgrapht" "dogstatsd"
   "anthropic-clj" "anthropic-sdk-clj" "buddy-auth"])

;; ---------------------------------------------------------------------------
;; Pure core (unit-tested; no IO)
;; ---------------------------------------------------------------------------

(defn median [xs]
  (let [s (vec (sort xs)) n (count s)]
    (when (pos? n)
      (if (odd? n)
        (nth s (quot n 2))
        (quot (+ (nth s (dec (quot n 2))) (nth s (quot n 2))) 2)))))

(defn feed->totals
  "Parse a daily stats EDN string into {artifact total} for one group. Reads the EDN
   properly (keys are [\"group\" \"artifact\"] vectors) so version-string digits can
   never leak into counts."
  [edn-str grp]
  (->> (edn/read-string edn-str)
       (keep (fn [[[g a] vmap]] (when (= g grp) [a (reduce + 0 (vals vmap))])))
       (into {})))

(defn baseline-breakers
  "Flag versions whose downloads exceed `factor`x the median of the OTHER versions
   AND clear an absolute `margin`. Uniform baselines (5,5,5,...) flag nothing; a lone
   spike does. Returns the flagged version maps with :median-siblings attached."
  [versions & {:keys [factor margin] :or {factor 2 margin 8}}]
  (when (> (count versions) 1)
    (for [{:keys [downloads] :as v} versions
          :let [others (keep-indexed (fn [_ x] (:downloads x))
                                     (remove #(identical? % v) versions))
                med (or (median others) 0)]
          :when (and (> downloads (* factor med))
                     (>= (- downloads med) margin))]
      (assoc v :median-siblings med))))

;; ---------------------------------------------------------------------------
;; IO
;; ---------------------------------------------------------------------------

(defn- get-body [url]
  (:body (http/get url {:follow-redirects :always :throw false})))

(defn fetch-artifact
  "API snapshot for one artifact -> {:artifact :total :versions [{:version :downloads}]}.
   Returns nil if the artifact 404s / has no JSON body."
  [a]
  (let [body (get-body (format "https://clojars.org/api/artifacts/%s/%s" group a))]
    (when (and body (str/starts-with? (str/trim body) "{"))
      (let [m (json/parse-string body true)]
        {:artifact a
         :total (:downloads m)
         :versions (mapv #(select-keys % [:version :downloads]) (:recent_versions m))}))))

(defn fetch-feed-day
  "Daily feed for YYYYMMDD -> {artifact total} for our group (empty map on miss)."
  [yyyymmdd]
  (let [body (get-body (str "https://clojars.org/stats/downloads-" yyyymmdd ".edn"))]
    (if (and body (str/starts-with? (str/trim body) "{"))
      (feed->totals body group)
      {})))

(defn- last-n-days [n]
  (let [today (java.time.LocalDate/now java.time.ZoneOffset/UTC)
        fmt (java.time.format.DateTimeFormatter/ofPattern "yyyyMMdd")]
    (map #(.format (.minusDays today %) fmt) (range 1 (inc n)))))

;; ---------------------------------------------------------------------------
;; Render
;; ---------------------------------------------------------------------------

(defn- pad [s n] (let [s (str s)] (str s (apply str (repeat (max 0 (- n (count s))) " ")))))

(defn- render-snapshot [rows]
  (let [total (reduce + 0 (map #(or (:total %) 0) rows))]
    (println (str "Clojars downloads — " group " — " (count rows) " artifacts, " total " lifetime"))
    (println (apply str (repeat 60 "-")))
    (doseq [{:keys [artifact total versions]} (sort-by #(or (:total %) 0) > rows)]
      (let [top (when (seq versions) (apply max-key :downloads versions))]
        (println (str "  " (pad artifact 20) (pad total 6)
                      "top " (:version top) "=" (:downloads top)))))))

(defn- render-feed [days]
  (println)
  (println (str "Daily pulls (last " (count days) " UTC days):"))
  (doseq [d days]
    (let [m (fetch-feed-day d)
          t (reduce + 0 (vals m))]
      (when (pos? t)
        (let [top (when (seq m) (key (apply max-key val m)))]
          (println (str "  " d "  " (pad t 5) "busiest: " top "=" (get m top))))))))

(defn- render-alerts [rows]
  (let [hits (for [{:keys [artifact versions]} rows
                   b (baseline-breakers versions)]
               (assoc b :artifact artifact))]
    (println)
    (if (seq hits)
      (do (println "*** ADOPTION SIGNAL — version(s) breaking from baseline ***")
          (doseq [{:keys [artifact version downloads median-siblings]} hits]
            (println (format "  %s %s = %d  (siblings median %d)"
                             artifact version downloads median-siblings))))
      (println "No adoption signal: every version at sibling baseline (crawler/cljdoc floor)."))
    (seq hits)))

(defn -main [& args]
  (let [feed-n (when-let [i (some->> args (drop-while #(not= % "--feed")) second)]
                 (parse-long i))
        rows (keep fetch-artifact artifacts)]
    (render-snapshot rows)
    (when feed-n (render-feed (last-n-days feed-n)))
    (let [signal (render-alerts rows)]
      (System/exit (if signal 1 0)))))
