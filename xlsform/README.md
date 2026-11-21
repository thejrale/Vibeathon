# XLSForm

- `eira_questionnaire.csv`: source question list. **Fill this with the complete EIRA questionnaire before Phase 1.** One row per question:
  - `section`: Patient Data / History / Examination / Result
  - `order`: position within the form
  - `question_text`: exact wording shown to the clinician
  - `answer_type`: text, integer, decimal, date, single choice, multiple choice, note, …
  - `options`: for choice questions, list as `code=Label; code=Label` (e.g. `asc_us=ASC-US; hsil=HSIL`)
  - `required`: yes / no
  - `validation`: e.g. `25–64 years`, `date not in the future`
  - `skip_logic`: when the question is shown, e.g. `only if Q12 = yes`
  - `notes`: anything else
  A Word/PDF copy of the official questionnaire can also be dropped in this folder.
- `citologia_eira_v1.xlsx`: built in Phase 1.
