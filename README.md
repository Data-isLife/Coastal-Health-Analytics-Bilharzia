# Coastal Kenya Bilharzia Analytics

## Project overview

I studied the spatial distribution and associated factors of bilharzia (schistosomiasis) among children aged 9–15 in Kenya's coastal region. I used R to clean and summarize the survey data, compare prevalence across sub-counties, examine demographic and WASH factors, and test whether nearby sub-counties had similar prevalence. I also built a Shiny dashboard so users can explore the cleaned results with filters and download the records they select.

The dashboard analyzes **`Project data.csv` only**. It does not use the individual-level source file in its analysis. If `Individual level data.csv` is included in the project folder, the app offers it as a separate download.

## Findings from my report and presentation

- The report and presentation report an overall prevalence of **6.34%** among children aged 9–15. The highest reported sub-county prevalence was **29.4% in Galole**, followed by **19.1% in Magarini** and **16.6% in Garsen**. **Mwatate** was lowest at about **0.20%**.
- Prevalence varied across sub-counties. The report gives a chi-squared test result of **p < 0.001**.
- The report found positive spatial autocorrelation: **Moran's I = 0.235, p = 0.000496**. High-prevalence areas tended to be near other high-prevalence areas.
- In the individual-level logistic model, the report gives an adjusted odds ratio of **1.291 for boys compared with girls** (p < 0.001). It reports no independent age association (OR **1.015**, p = **0.326**).
- The report gives adjusted odds ratios of **0.575 for its safe-water indicator** and **0.442 for toilet availability**, both with p < 0.001. These interpretations depend on the original indicator coding.
- In the sub-county linear model, the report gives an adjusted R² of **0.474**. Toilet coverage was associated with lower prevalence (β = **−0.170**, p = **0.012**); the other listed aggregate predictors were not statistically significant at the 0.05 level.

These are observational findings from a cross-sectional study. They show associations, not proof that a factor caused infection. The water-source and toilet codes should be interpreted alongside the study's codebook.

### Data consistency note

My report and presentation state that the analysis included **26,188** children. The current `Project data.csv` contains **26,118** records, including 1,655 positive `anyshito` results. That file gives a prevalence of about **6.34%**. I should reconcile the 70-record difference against the final analysis dataset before treating the report and dashboard as a single finalized release.

The report also describes the correlation between the proportion of males and prevalence as statistically significant at p = 0.1256. Since that p-value is above 0.05, I interpret that aggregate correlation as **not statistically significant**.

## Skills I developed and applied

- **R programming and data preparation:** reading CSV data, cleaning missing or inconsistent values, recoding variables, and aggregating observations by location.
- **Statistical analysis:** prevalence estimation, chi-squared tests, Welch's t-test, Pearson correlation, logistic regression, and linear regression.
- **Spatial epidemiology:** linking observations to geographic coordinates, building a 5-nearest-neighbor spatial weights matrix, calculating Global Moran's I, and identifying geographic hotspots.
- **Data visualization:** presenting geographic, demographic, environmental, and model results in charts, tables, and interactive maps.
- **Shiny application development:** building reactive filters, coordinated dashboard views, data tables, and filtered CSV downloads.
- **Research communication:** reviewing literature, defining research questions and hypotheses, interpreting statistical results, and communicating findings in a written report and presentation.
- **Reproducible and responsible analysis:** separating the cleaned analysis data from the original source file, documenting coding limitations, and distinguishing association from causation.

## Use the dashboard

1. Open the **Analysis filters** panel.
2. Choose a county and sub-county, gender, age range, water-source value, and toilet value.
3. Choose whether to include records with missing age.
4. Select **Apply filters** to refresh the charts, map, summaries, tables, and cleaned-data download together. Select **Reset filters** to return to the full dataset.
5. The charts show missing outcome, water, and toilet values explicitly where those records are present.

The cleaned file contains the bilharzia outcome `anyshito`; it does not provide separate disease outcomes. Gender is standardized in the app to **Male** and **Female**. The map shows the six coastal counties using bundled county boundary data and sub-county coordinates from `Project data.csv`. It works without map tiles, an API key, or a live map service. Its points should not be read as ward- or village-level locations. Boundary source and license details are included in `BOUNDARY_DATA_LICENSE.txt`; the source project is [keAdminBounds](https://github.com/r115/keAdminBounds).

## Run and deploy to Posit Connect Cloud

I can run the app in Posit Cloud as a development workspace, then deploy it to my [Data-isLife Connect Cloud space](https://connect.posit.cloud/data-islife). Connect Cloud supports Shiny for R deployments from GitHub, RStudio, Positron, VS Code, or the R console. Current instructions are in Posit's [Shiny for R deployment guide](https://docs.posit.co/connect-cloud/how-to/r/shiny-r.html).

### Prepare the project

Keep these files together in the project directory:

- `app.R`
- `Project data.csv`
- `coastal_counties.csv` and `BOUNDARY_DATA_LICENSE.txt` for the offline county map
- `renv.lock` for deployment from GitHub or an IDE
- `downloads/` if I want to offer extra files
- `Individual level data.csv` only if I intend to offer that original file as a download

The app does not install packages when it starts. In the project R console, I can create the dependency lock file and capture the packages used by the app:

```r
install.packages("renv")
renv::init()
install.packages(c("shiny", "bslib", "bsicons", "dplyr", "ggplot2", "plotly", "DT"))
renv::snapshot()
```

I should keep the resulting `renv.lock` beside `app.R` and include it when I deploy. Connect Cloud requires a `renv.lock` or `manifest.json` for GitHub-based R deployments; its IDE workflow uses `renv.lock`. See Posit's [R dependency guide](https://docs.posit.co/connect-cloud/how-to/r/dependencies.html).

### Deploy from VS Code

1. Install Posit's **Posit Publisher** extension in VS Code.
2. Open this project folder and connect the extension to my Connect Cloud account.
3. Create a deployment, select `app.R` as the primary file, and check that `Project data.csv`, `renv.lock`, and any intended downloads are included in the project files.
4. Deploy to the Data-isLife Connect Cloud account and open the resulting app link.

I can also deploy through GitHub by committing the app, data, dependency lock file, and any public download files, then selecting the repository and `app.R` in Connect Cloud. On a free Connect Cloud account, GitHub-based deployments require a public repository, so I should not use that route for private or sensitive data. The deployment guide describes other options.

## Add documents for users to download

The app has a **Downloads** page. To add a document:

1. Put the file in the project's `downloads/` folder. The app lists PDF, Word (`.docx`), PowerPoint (`.pptx`), Excel (`.xlsx`), CSV, and text (`.txt`) files found there.
2. Include the file in the deployment. For GitHub, commit and push it. For VS Code/Posit Publisher, ensure it is selected in the project files list.
3. Redeploy the app. The file will then appear as a download button on the **Downloads** page.

I should only put files in this folder that I intend app users to access. The project report and presentation contain author and supervisor details, so I should not add them unless I want those details distributed with the app.

## API keys

The current app needs **no API key**. The cleaned data and county boundary map are bundled as local files, so no map tiles or live map service are called. If I later connect an external service that requires an API key, I should obtain the key from that service's developer account, then add it in Connect Cloud under the app's **Content Settings → Variables**. In R, I can read it with `Sys.getenv("MY_SERVICE_API_KEY")`. I should never put a real key in `app.R` or commit it to GitHub. See Posit's [secret-variable instructions](https://docs.posit.co/connect-cloud/user/publish/github.html).

## Limitations and next steps

- The study is cross-sectional, so its regression results do not establish causation.
- The available environmental measures are water source and toilet access. A codebook is needed to interpret their recorded values reliably.
- The spatial analysis uses sub-county points. Ward boundary data would support finer mapping.
- I should reconcile the 26,188 report sample with the 26,118 records in the current cleaned CSV before presenting both as final.
- Future work could add ward-level spatial models, evaluate intervention costs, and study local barriers to toilet access.
