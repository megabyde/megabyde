# Aggregating benchmark metrics with missing results

## Define the metric before you aggregate it

For benchmark $i$ and configuration $X \in \{A, B\}$, let $w_i \ge 0$ be the benchmark importance
weight.

The first step is to decide what kind of metric you are aggregating. In practice, most benchmark
metrics fall into one of two buckets.

### Ratio metrics built from additive quantities

Some metrics are ratios of components that add across workloads. Let:

- $n_{Xi}$ be the numerator contribution for benchmark $i$
- $d_{Xi}$ be the denominator contribution for benchmark $i$
- $m_{Xi} = n_{Xi} / d_{Xi}$ be the per-benchmark metric

Then the aggregate metric is:

```math
\widehat{M}_X
=
\frac{\sum_i w_i n_{Xi}}
     {\sum_i w_i d_{Xi}}
```

Examples include IPC, cache miss rate, work per joule, and any other metric that is naturally
defined as a ratio of totals.

This is not the same as a weighted mean of per-benchmark metric values unless the weights happen to
be proportional to the denominator.

### Benchmark-level scores

Other metrics are already defined at the benchmark level. Let $m_{Xi}$ be the score you want to
aggregate. Then a natural aggregate is the weighted mean:

```math
\bar{M}_X
=
\frac{\sum_i w_i m_{Xi}}
     {\sum_i w_i}
```

If your suite defines a different rule, such as a geometric mean of normalized ratios, use that rule
explicitly instead of silently switching to an arithmetic mean.

Everything that follows depends on getting this estimand right first. If the suite-level metric is
wrong, the interval, comparison, and missing-data handling will all be wrong in the same direction.

## Work through a small example

Suppose a metric is defined as a ratio of totals, and configuration $X$ has two benchmarks with
equal weights:

- Benchmark 1: $n_{X1} = 2$, $d_{X1} = 1$, so $m_{X1} = 2.0$
- Benchmark 2: $n_{X2} = 9$, $d_{X2} = 9$, so $m_{X2} = 1.0$

The aggregate ratio metric is:

```math
\widehat{M}_X
=
\frac{2 + 9}{1 + 9}
=
1.1
```

The weighted mean of the two per-benchmark values is:

```math
\bar{M}_X
=
\frac{2.0 + 1.0}{2}
=
1.5
```

Those are different answers because the second benchmark carries much more denominator mass. If the
metric is a ratio-of-totals quantity, then $1.1$ is the aggregate that matches the workload mix. If
the metric is a benchmark-level score, then the weighted mean may be the right answer instead.

## Quantify uncertainty carefully

Benchmark suites are curated. Their weights are importance weights, not sampling probabilities. That
means a 95% interval is usually better interpreted as a suite stability interval than as literal
population coverage.

That is still useful. The interval tells you how sensitive the aggregate is to the particular
workload mix in the suite.

## Use a paired bootstrap as the default

For most benchmark comparisons, the paired bootstrap is the cleanest default.[^1]

1. Resample benchmark indices with replacement.
2. Keep each benchmark's weight and all measurements for that benchmark together.
3. Recompute the aggregate metric or the comparison statistic for each resample.
4. Form percentile or BCa intervals from the resampled distribution.

The important detail is pairing. If benchmark $i$ has results for both $A$ and $B$, the resample
must keep that pair together. Treating the two configurations as independent samples discards
correlation that is actually present in the data.

The paired bootstrap works for weighted means, ratio metrics, and most practical comparison
statistics.

## Use the delta method for ratio metrics when you want a fast analytic approximation

For ratio-of-totals metrics, define:

```math
a_i = w_i n_{Xi}, \qquad
b_i = w_i d_{Xi}, \qquad
\hat{r} = \frac{\bar{a}}{\bar{b}}
```

Then the delta method gives the first-order approximation:[^2] [^3]

```math
\mathrm{Var}(\hat{r})
\approx
\frac{1}{n}
\left(
\frac{s_{aa}}{\bar{b}^2}
+
\frac{\bar{a}^2}{\bar{b}^4}s_{bb}
-
\frac{2\bar{a}}{\bar{b}^3}s_{ab}
\right)
```

where $s_{aa}$, $s_{bb}$, and $s_{ab}$ are the sample variance and covariance terms across
benchmarks.

This gives a quick standard error without resampling. If the metric is positive, a log-scale
interval is often more stable:

```math
\log \hat{r} = \log \bar{a} - \log \bar{b}
```

For benchmark-level weighted means, simpler weighted-mean formulas are often enough, but using the
paired bootstrap for everything is usually easier to explain and harder to misuse.

## Check weight concentration

Unequal weights reduce the amount of information in the suite. A simple diagnostic is Kish effective
sample size:[^4]

```math
n_{\mathrm{eff}}
=
\frac{\left(\sum_i w_i\right)^2}
     {\sum_i w_i^2}
```

Interpret it as a concentration metric:

- If all weights are equal, then $n_{\mathrm{eff}} = n$.
- If one benchmark dominates, then $n_{\mathrm{eff}}$ collapses toward 1.

This is not a substitute for the actual number of workloads, but it is a useful warning sign that
the suite-level result is being driven by a small part of the benchmark set.

## Compare configurations on the common suite

Let $S_A$ and $S_B$ be the benchmarks that completed successfully on each configuration. For clean
performance comparisons, use the common suite:

```math
S = S_A \cap S_B
```

Then compare either:

```math
\Delta = \widehat{M}_{B,S} - \widehat{M}_{A,S}
```

or:

```math
R = \frac{\widehat{M}_{B,S}}{\widehat{M}_{A,S}}
```

with the obvious substitution of $\bar{M}$ if your aggregate is a weighted mean rather than a ratio
metric.

This matters because comparing $A$ on one benchmark set and $B$ on another mixes a performance claim
with a coverage claim. That can be valid, but it should be an explicit choice, not an accident.

## Treat missing benchmarks as missing data

Now suppose configuration $B$ fails some benchmarks that $A$ completes. Once that happens, there are
two different estimands:

- The common-suite aggregate over $S_A \cap S_B$, which is identifiable from observed data.
- The full-suite aggregate over the intended target suite, which is not identifiable without extra
  assumptions.[^5]

This is standard missing-data territory. If failures are related to the unobserved outcome, the
missingness is effectively MNAR and the full-suite quantity cannot be recovered from observed runs
alone.

The exact consequence depends on the metric family.

### If the metric is a benchmark-level score

If each missing benchmark score is known to lie between $m_{\min}$ and $m_{\max}$, then the
weighted-mean aggregate can be bounded directly:

```math
\frac{\sum_{i \in S_B} w_i m_{Bi} + \sum_{i \notin S_B} w_i m_{\min}}
     {\sum_i w_i}
\le
\bar{M}_B
\le
\frac{\sum_{i \in S_B} w_i m_{Bi} + \sum_{i \notin S_B} w_i m_{\max}}
     {\sum_i w_i}
```

That gives a straightforward sensitivity analysis.

## References

[^1]: Efron, B., and Tibshirani, R.J. _An Introduction to the Bootstrap_. CRC Press, 1993.

[^2]: [Delta method](https://en.wikipedia.org/wiki/Delta_method)

[^3]: Lohr, S.L. _Sampling: Design and Analysis_. Duxbury Press, 1999. ISBN 9780534353612.

[^4]:
    Kish, L. _Survey Sampling_. Wiley, 1965.
    [Design effect overview](https://en.wikipedia.org/wiki/Design_effect)

[^5]: Little, R.J.A., and Rubin, D.B. _Statistical Analysis with Missing Data_. Wiley, 2002.
