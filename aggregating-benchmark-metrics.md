# Aggregating benchmark metrics with missing results

Missing benchmark results create two separate problems. First, you need the right suite-level
metric. Second, you need to decide which quantity is still identifiable once some workloads fail. If
those problems are mixed together, the aggregate, interval, and comparison can answer different
questions.

## Define the estimand before you aggregate

For benchmark $i$ and configuration $X \in \{A, B\}$, let $w_i \ge 0$ be the benchmark importance
weight. In practice, most benchmark metrics fall into one of two families.

### Ratio metrics built from additive quantities

Some metrics are ratios of components that add across workloads. Let:

- $n_{Xi}$ be the numerator contribution for benchmark $i$
- $d_{Xi}$ be the denominator contribution for benchmark $i$
- $m_{Xi} = n_{Xi} / d_{Xi}$ be the per-benchmark metric

Then the suite-level metric is:

```math
\widehat{M}_X
=
\frac{\sum_i w_i n_{Xi}}
     {\sum_i w_i d_{Xi}}
```

This covers IPC, cache miss rate, work per joule, and any other quantity that is naturally defined
as a ratio of totals.

This is itself a weighted mean of the per-benchmark values $m_{Xi}$, but with effective weights
$w_i d_{Xi}$ rather than $w_i$. Benchmarks with large denominators carry proportionally more of the
aggregate, and the two weightings agree only when every benchmark contributes the same denominator.

### Benchmark-level scores

Other metrics are already defined at the benchmark level. Let $m_{Xi}$ be the score to aggregate.
Then a natural suite-level aggregate is the weighted mean:

```math
\bar{M}_X
=
\frac{\sum_i w_i m_{Xi}}
     {\sum_i w_i}
```

If the suite defines a different aggregation rule, use that rule directly instead of silently
replacing it with an arithmetic mean.

### Geometric means

Suites such as SPEC CPU aggregate normalized ratios with a weighted geometric mean:

```math
\tilde{M}_X
=
\exp\left(
\frac{\sum_i w_i \log m_{Xi}}
     {\sum_i w_i}
\right)
```

This applies the weighted mean from the previous section to $\log m_{Xi}$, so everything below
transfers without modification: resample benchmarks, aggregate on the log scale, and exponentiate at
the end.

It is defined only for strictly positive $m_{Xi}$, which is why a failed measurement cannot simply
be recorded as zero and averaged in. A single zero sends the aggregate to zero, and that is a
missing-data problem rather than a very bad score.

This step is structural, not cosmetic. If the estimand is wrong, the interval and missing-data
treatment will describe the wrong quantity.

## A small example

Suppose the metric is a ratio of totals and configuration $X$ has two benchmarks with equal weights:

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

Those are different answers because benchmark 2 carries much more denominator mass. If the metric is
a ratio-of-totals quantity, then $1.1$ is the aggregate that matches the workload mix. If the metric
is a benchmark-level score, then the weighted mean may be the right aggregate instead.

## Interpret uncertainty as suite stability

Benchmark suites are curated. Their weights are importance weights, not sampling probabilities. In
most cases, a 95% interval is therefore better interpreted as a suite stability interval than as a
literal population-coverage statement.

That interpretation is still useful. It tells you how sensitive the aggregate is to the particular
workload mix represented by the suite.

## Use a paired bootstrap as the default

For most benchmark comparisons, use a paired bootstrap by default.[^1]

1. Resample benchmark indices with replacement.
2. Keep each benchmark's weight and all measurements for that benchmark together.
3. Recompute the aggregate metric or comparison statistic for each resample.
4. Form percentile or BCa intervals from the resampled distribution.

The important detail is pairing. If benchmark $i$ has results for both $A$ and $B$, the resample
must keep that pair together. Treating the two configurations as independent samples throws away
correlation that is actually present in the data.

Note what this does and does not cover. Resampling benchmark indices propagates uncertainty about
the workload mix, which is the suite stability reading above. It says nothing about run-to-run
measurement noise. If replicate runs matter for your setup, use a two-level bootstrap: resample
benchmarks, then resample runs within each selected benchmark, and recompute the aggregate from the
resampled runs.

The same bootstrap machinery works for weighted means, ratio metrics, and most practical comparison
statistics. For a ratio-of-totals metric compared across two configurations:

```python
import numpy as np


def paired_bootstrap(n_a, d_a, n_b, d_b, w, reps=10_000, seed=0):
    """Percentile interval for the ratio of B's aggregate to A's."""
    rng = np.random.default_rng(seed)
    idx = rng.integers(0, len(w), (reps, len(w)))

    def aggregate(n, d):
        return (w[idx] * n[idx]).sum(axis=1) / (w[idx] * d[idx]).sum(axis=1)

    return np.percentile(aggregate(n_b, d_b) / aggregate(n_a, d_a), [2.5, 97.5])
```

The shared `idx` preserves the pairing: both configurations are recomputed on the same resampled
benchmarks. Drawing independent index sets discards the correlation between $A$ and $B$, so the
interval no longer describes the paired comparison.

## Use the delta method when you want a fast analytic approximation

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

```math
\mathrm{Var}(\log \hat{r})
\approx
\frac{1}{n}
\left(
\frac{s_{aa}}{\bar{a}^2}
-
\frac{2s_{ab}}{\bar{a}\bar{b}}
+
\frac{s_{bb}}{\bar{b}^2}
\right)
```

Build the interval on the log scale and exponentiate the endpoints. That keeps the interval positive
and avoids the asymmetry you get from a symmetric interval around a ratio.

For benchmark-level weighted means, simpler formulas are often enough. In practice, though, using
the paired bootstrap for both metric families is usually easier to explain and harder to misuse.

## Check weight concentration

Unequal weights reduce the amount of information carried by the suite. A simple diagnostic is Kish
effective sample size:[^4]

```math
n_{\mathrm{eff}}
=
\frac{\left(\sum_i w_i\right)^2}
     {\sum_i w_i^2}
```

Interpret it as a concentration metric:

- If all weights are equal, then $n_{\mathrm{eff}} = n$.
- If one benchmark dominates, then $n_{\mathrm{eff}}$ collapses toward 1.

This is not a substitute for the actual number of workloads. It is a warning sign that the
suite-level result is being driven by a small part of the benchmark set.

## Compare configurations on the common suite

Let $S_A$ and $S_B$ be the benchmarks that completed successfully on each configuration. For a clean
performance comparison, use the common suite:

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

For a weighted-mean aggregate, substitute $\bar{M}$ for $\widehat{M}$.

This matters because comparing $A$ on one benchmark set and $B$ on another mixes a performance claim
with a coverage claim. That can be a valid quantity, but it should be an explicit choice.

## Treat missing benchmarks as missing data

Now suppose configuration $B$ fails some benchmarks that $A$ completes. At that point there are two
different estimands:

- The common-suite aggregate over $S_A \cap S_B$, which is identifiable from observed data.
- The full-suite aggregate over the intended target suite, which is not identifiable without extra
  assumptions.[^5]

This is standard missing-data territory. If failures are related to the unobserved outcome, the
missingness is effectively MNAR and the full-suite quantity cannot be recovered from observed runs
alone.

Even when its magnitude is unknown, the direction can often be identified. If $B$ fails the
workloads it handles worst, then $S_A \cap S_B$ excludes exactly the cases where $B$ looks bad, and
the common-suite comparison is optimistic for $B$. Report the failure list next to the aggregate and
state which configuration the exclusions favour.

The consequence depends on the metric family.

### If the metric is a ratio of totals

Here the bound needs the numerator and the denominator separately. Write the observed totals and the
missing weight as:

```math
N = \sum_{i \in S_B} w_i n_{Bi},
\qquad
D = \sum_{i \in S_B} w_i d_{Bi},
\qquad
W = \sum_{i \notin S_B} w_i
```

Suppose every missing benchmark satisfies $n_{\min} \le n_{Bi} \le n_{\max}$ and
$d_{\min} \le d_{Bi} \le d_{\max}$. The aggregate increases in the numerator and decreases in the
denominator, so the extremes sit at opposite corners:

```math
\frac{N + W n_{\min}}{D + W d_{\max}}
\le
\widehat{M}_B
\le
\frac{N + W n_{\max}}{D + W d_{\min}}
```

This assumes the two components can be bounded independently. If you can bound the per-benchmark
ratio $m_{Bi}$ instead, the effective-weight form from the first section gives a tighter result. The
two components move the bound in opposite directions, which is why bounding a ratio metric takes
more prior information than bounding a score.

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

That gives a simple sensitivity analysis instead of pretending the missing workloads do not matter.

## References

[^1]: Efron, B., and Tibshirani, R.J. _An Introduction to the Bootstrap_. CRC Press, 1993.

[^2]: [Delta method](https://en.wikipedia.org/wiki/Delta_method)

[^3]: Lohr, S.L. _Sampling: Design and Analysis_. Duxbury Press, 1999. ISBN 9780534353612.

[^4]:
    Kish, L. _Survey Sampling_. Wiley, 1965.
    [Design effect overview](https://en.wikipedia.org/wiki/Design_effect)

[^5]: Little, R.J.A., and Rubin, D.B. _Statistical Analysis with Missing Data_. Wiley, 2002.
