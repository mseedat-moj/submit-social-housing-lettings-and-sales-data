## 2022-08-30

### 1. Install ruby 3.1.2 & Gemfile on Mac Intel
- like use of overcommit, new to me, seems useful
- ran rails db:setup, worked first time
- setup instructions are great, although ran into issue with old node version which needed upgrading and then webpacker was not working. eventually resolved.


### 2. System design
General system design seems to be: a big chunk of work dedicated to disecting giant excel files and a sub-system to complement that data. Not sure if Forms are only editable once there is an entry bulk-uploaded into the Case_Logs table. System seems fairly well structured at the moment with use of MVC, API wrappers in /services and complementary rake tasks. 

### 3. Controllers
Some controllers have logic that should be in models or properly unit tested separate classes, doesn't affect functionality but contributes to better separation of concerns/maintainability. Generally seems to be in a good place as features are still limited.

form_controller possibly getting out of hand. 

### 4. Models
in models/location.rb
Interesting setting up of `PIO = PostcodeService.new` presumably to act like a Singleton? Seems too easy to misuse at the moment

in models/user.rb
Nitpick some java style `.is_xxx` rather than just `.xxx?`

Would like to see more comments about what the various models represent and how they

### 5. models/bulk_upload.rb
I can see case_logs database table is populated by individual bulk_upload models which are directly fed in via Excel spreadsheets.

bulk_upload should ideally be wrapped in a transaction at the moment any exceptions are swallowed so the initial bare-bones case log entry is created and then potentially leave inconsistent data.

The main crux of the data import is on Line 37 which seems to perform `case_log.update` 128 times per row in the excel spreadsheet. Is that right? If so I would like to understand the rationale for that other than to ensure continued operation in the event of failure for 1 of the attributes being rejected by the DB. Is that because the data being uploaded is often very unreliable/poor quality? And is this a bottleneck or are data-sets small enough for this not to be a problem (yet?).

### 6. Case Logs database table
As to whether the case_logs table should be further normalised: The CaseLog table is being used as the place where 'Load' stage of the bulk upload ETL pipeline is performed hence why the table reflects the huge number of columns in the uploaded Excel spreadsheet. In a way, each row in CaseLog is more like a freeform document in a no-sql db, resulting in lots of meta-programming. There are lots of code calls that look similar to:

```
  case_log.public_send(argument["key"])

  case_log.send(condition.keys.first)

  etc
```

As a result, as complexity in the incoming data increases, it will become more difficult to reason about output based on current state. Validation should not be an issue as the data columns are fixed and agreed upon beforehand. However there could be issues going forward where validation rules become more 'dynamic'/'contextual' e.g. dependent on housing provider etc making the code more convoluted as a result. 

There's also the risk of the Excel spreadsheet columns driving the data/domain design of the system and therefore resulting in a highly coupled and hard to test/change system. Some level of decoupling between the incoming Excel spreadsheet data and the representation fo that data through appropriate domain design would be a good step for the future.

The current system design reflects the need to develop a proof-of-concept and does the job in that regard. I like the inclusion of capybara based tests and there's a good set of tests in the spec folder. 

### 7. Conclusion
It's a straightforward MVC project and most importantly the very hard / tedious work of converting the very complicated excel file has been done giving the team opportunity to refactor.
