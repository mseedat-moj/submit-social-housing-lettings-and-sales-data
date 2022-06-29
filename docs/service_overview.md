# Service overview

All lettings and and sales of social housing in England need to be logged with the Department for levelling up, housing and communities (DLUHC). This is done by Local Authorities and Housing Associations, who are the primary users of this service. Data is collected via a form that runs on an annual data collection window basis. Form changes are made annually to add new questions, remove any that are no longer needed, or adjust wording or answer options etc. Each data collection window runs from 1st April to 1st April + an extra 3 months to allow for any late submissions, meaning that between April and July, two collection windows are open simultaneously and logs can be submitted for either.

ADD (Analytics & Data Directorate) statisticians are the other primary users of the service. The data collected is transferred to DLUHCs data warehouse (CDS - consolidated data store), via nightly exports to XML which are transferred to S3 and ingested from there. CDS ingests and transforms the data, ultimately storing it in a MS SQL database and exposing it to analysts and statisticians via Amazon Workspaces.