create table if not exists purchase_attachments (
    id bigint primary key auto_increment,
    document_type varchar(32) not null,
    document_id bigint not null,
    file_name varchar(255) not null,
    file_url varchar(1024) not null,
    content_type varchar(128) null,
    created_by_email varchar(255) null,
    created_at datetime(6) not null default current_timestamp(6)
);

create index idx_purchase_attachments_document
    on purchase_attachments (document_type, document_id, created_at desc);
