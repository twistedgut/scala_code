-- http://jira.nap/browse/TP-698

-- "Build constants goes squiffy if there are duplicate rows in
-- correspondence_templates with the same name and department_id fields. A
-- unique index would stop this from happening in error."

BEGIN;
    CREATE UNIQUE INDEX idx_correspondence_templates_name_department_id
        ON public.correspondence_templates(name, department_id);
COMMIT;
