# Check the 2029 outliers
gap_raw |> filter(year >= 2027) |> arrange(desc(year))

# Check the very early years — 2010 is surprisingly far back
gap_raw |> filter(year <= 2012) |> arrange(year)