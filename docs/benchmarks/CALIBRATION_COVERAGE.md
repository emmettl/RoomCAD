# Calibration target measurement coverage

The calibration report must distinguish targeted bands from bands with an available
preview T30. Before this change, a best step with one measured target exactly met
and one unavailable target reported "preview T30 within 0% of the targets". A step
with all targeted measurements unavailable reported "within — of the targets".
Neither describes agreement for the unavailable bands.

The summary now gives the available/targeted count and marks the rest unavailable;
when all targeted bands are unavailable it reports that directly. A fully measured
summary keeps its existing wording. Two focused reporting tests reproduce the old
coverage ambiguity and pass after the change.

The numerical calibration source, decay extraction, best-step selection, material
factors, saturation, simulation, saved identities, measured fixtures and exact Core
alpha.18 pin are unchanged. The existing two calibration tests pass before the
change. This closes a reporting gap, not the larger availability/convergence policy
or independently selected band's agreement in the assembled final room. Those are
separate model audits; no empirical acoustic accuracy is established here.
