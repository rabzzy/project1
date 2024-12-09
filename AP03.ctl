LOAD DATA
INFILE *
APPEND
INTO TABLE AP_INVOICE_IFACE_STG_03
FIELDS TERMINATED BY "," 
OPTIONALLY ENCLOSED BY '"'
TRAILING NULLCOLS
(
                                  Invoice_type,
Invoice_num, 
Curr_code, 
Vendor_number,
Vendor_site, 
Payment_term,
Line_number,
Description,
Header_amount, 
Line_amount, 
Source, 
Distribution_set_name
)