(ns clojars-stats-test
  (:require [clojure.test :refer [deftest testing is]]
            [clojars-stats :as cs]))

(deftest median-test
  (is (nil? (cs/median [])))
  (is (= 5 (cs/median [5])))
  (is (= 5 (cs/median [1 5 9])))
  (is (= 4 (cs/median [2 6]))))            ; even count -> mean of middle two

(deftest feed->totals-test
  (testing "parses a Clojars daily stats EDN map, summing per artifact for one group"
    (let [edn (str "{[\"net.clojars.savya\" \"anthropic-clj\"] {\"0.6.0\" 5, \"0.5.0\" 3}, "
                   "[\"net.clojars.savya\" \"jackdaw\"] {\"1.3.4\" 7}, "
                   "[\"other.group\" \"x\"] {\"1.0\" 99}}")]
      (is (= {"anthropic-clj" 8 "jackdaw" 7}
             (cs/feed->totals edn "net.clojars.savya")))))
  (testing "empty / no-match group yields empty map"
    (is (= {} (cs/feed->totals "{[\"a\" \"b\"] {\"1.0\" 1}}" "net.clojars.savya")))))

(deftest baseline-breakers-test
  (testing "uniform per-version counts (crawler fingerprint) flag nothing"
    (is (empty? (cs/baseline-breakers
                 [{:version "0.6.0" :downloads 5} {:version "0.5.0" :downloads 5}
                  {:version "0.4.0" :downloads 5} {:version "0.3.0" :downloads 5}]))))
  (testing "a single version pulling far ahead of siblings is flagged (real dependent)"
    (let [bs (cs/baseline-breakers
              [{:version "0.6.0" :downloads 40} {:version "0.5.0" :downloads 5}
               {:version "0.4.0" :downloads 5} {:version "0.3.0" :downloads 6}])]
      (is (= ["0.6.0"] (map :version bs)))
      (is (= 5 (:median-siblings (first bs))))))
  (testing "small absolute lead under margin is not flagged even if ratio is high"
    (is (empty? (cs/baseline-breakers
                 [{:version "0.2.0" :downloads 3} {:version "0.1.0" :downloads 1}]))))
  (testing "single version has no siblings -> never a breaker"
    (is (empty? (cs/baseline-breakers [{:version "0.1.0" :downloads 99}])))))
