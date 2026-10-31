-- Private temporary object storage for student-requested JSON data exports.
insert into storage.buckets(id,name,public,file_size_limit,allowed_mime_types)
values('data-exports','data-exports',false,20971520,array['application/json'])
on conflict(id) do update set public=false,file_size_limit=excluded.file_size_limit,allowed_mime_types=excluded.allowed_mime_types;
