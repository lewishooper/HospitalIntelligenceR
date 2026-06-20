# June  2026

Please review:

- the session summary for June 19 pm, 2026
- The BoardMinutes_phase2_analysisWorkPlan.md
- Claude_working_preferences.md

Please review the following notes on the session summary for june 19 PM 

## Notes on Session summary June 19/2026pm



next Session

Agree with Current priority steps

Classifier Patch

Do we need to execute the classifier patches, since we are no longer using the minutes.classify.r?

Agree with changes to FAC 644 in the Audit, but if we are going to focus on folders for extraction not the audit file. how will this be  useful



Extract_minutes.R design specification.

Core principles and Architecture

I like the folder based logic, but have we dealt approriately with the partner Issues? esp 644 Cornwall, I think we dealt with it in the audit file but it looks like we are not using that anymore?
I know there are multiple partnerships in the hospital field, and I suspect this is not the only one. 

Here is my suggestion.  Lets run the extract_minutes file without considering partners and the create a find_partners.R script, that looks for partnerships based on the minutes, i.e. it identifies duplicate minutes and the FAC to which it belongs. This will help clarify the partners.  I would also suggest that this be designed so that it can be used for strategic plans, where we know parterships create identical plans?? We can create this after we finalize extract_minutes.r

Output  In the rare case where 2 sets of minutes are found we will need to be able to split these at some point in the future. 
Also lets capture the date from the minutes in the output data
 This date will be more accurate than the file date often included in the file name

Fallback end.  Great idea.

Carry forward section

Let's drop reference to and use of BoardPro data.  They are a proprietary company and we dont want to infringe on their IP. Besides, their notion of board motions is prescriptive, not descriptive. 