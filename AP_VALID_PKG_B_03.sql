create or replace package body AP_VALID_PKG_03 as
   gn_request_id       NUMBER ; 
   gn_user_id          NUMBER ;
   gn_org_id           NUMBER ;
   gn_organization_id  NUMBER ; 
   gc_val_status       VARCHAR2 ( 10 ) := 'VALIDATED';
   gc_err_status       VARCHAR2 ( 10 ) := 'ERROR';
   gc_new_status       VARCHAR2 ( 10 ) := 'NEW';
   
   Procedure main (p_errbuf  OUT NOCOPY Varchar2,
                   p_retcode OUT NOCOPY Number) is
                   
  Cursor cur_po_order_header
     IS
            SELECT          XPOIS.vendor_number
                          , XPOIS.vendor_id
                          , XPOIS.document_type_code
                          , XPOIS.agent_number
                          , XPOIS.ship_to_location
                          , XPOIS.ship_to_location_id
                          , XPOIS.bill_to_location
                          , XPOIS.bill_to_location_id
                          , XPOIS.curr_code
                    FROM  PURCHASE_ORDER03_STG  XPOIS
                    WHERE UPPER(XPOIS.record_status) = gc_new_status
                    GROUP BY XPOIS.vendor_number
                           , XPOIS.vendor_id
                           , XPOIS.document_type_code
                           , XPOIS.agent_number
                           , XPOIS.ship_to_location
                           , XPOIS.ship_to_location_id
                           , XPOIS.bill_to_location
                           , XPOIS.bill_to_location_id
                           , XPOIS.curr_code  ;
   Cursor  cur_po_order_lines (
                                 p_vendor_number        IN VARCHAR2
                               , p_ship_to_location     IN VARCHAR2
                               , p_bill_to_location     IN VARCHAR2
                               )
     IS
       SELECT XPOIS.*
       FROM   PURCHASE_ORDER03_STG  XPOIS
       WHERE  XPOIS.vendor_number          = p_vendor_number
       AND    XPOIS.ship_to_location       = p_ship_to_location
       AND    XPOIS.bill_to_location       = p_bill_to_location;

   --Local Variables
     ln_batch_id          Number;
     ln_po_header_id      Number;
     l_curr_code          Number;
     l_error_flag         Number :=0;
     l_vendor_id          Number;
     l_agent_id           Number;
     l_agent_name         varchar2(100);
     l_inventory_item_id  number;
     ln_po_line_id        number;
     counter              number:=0;

   begin
        mo_global.init('PO');
        
        mo_global.set_policy_context('S',FND_PROFILE.VALUE('USER_ID')); 
        fnd_file.put_line (fnd_file.output,FND_PROFILE.VALUE('USER_ID'));
        gn_request_id      := FND_GLOBAL.CONC_REQUEST_ID;              
                                  gn_user_id         := nvl(FND_PROFILE.VALUE('USER_ID'),-1);         
                                  gn_org_id          := nvl(FND_PROFILE.VALUE('ORG_ID'),204);  
                                  gn_organization_id := TO_NUMBER (OE_PROFILE.VALUE('SO_ORGANIZATION_ID'));
        --
        --Get Batch ID from standard sequence
        --
        select MSC_ST_BATCH_ID_S.nextval 
               into
               ln_batch_id 
        from   dual;
        dbms_output.put_line(ln_batch_id );
        
        FND_FILE.PUT_LINE(FND_FILE.LOG,'Batch ID : '||ln_batch_id);
        FND_FILE.PUT_LINE(FND_FILE.output,'Batch ID : '||ln_batch_id);
        for   i in cur_po_order_header loop
              counter := 0;
              --Get Interface Header ID from sequence
              select PO_HEADERS_INTERFACE_S.nextval
                into ln_po_header_id
                from dual;             
              --Lets Validate
              --1. Currency Code
               FND_FILE.PUT_LINE(FND_FILE.output,'Header Id : '||ln_po_header_id);
              
             begin
               AP_VALID_PKG_03.Validate_Currency_03(i.curr_code,l_curr_code );
               if l_curr_code = 2 then
                  FND_FILE.PUT_LINE(FND_FILE.LOG,'Currency code does not exist'||i.curr_code);
                  dbms_output.put_line('currency');
                  l_error_flag :=1;
               end if;
             end;   
             
             --Validate and get Vendor ID
             l_vendor_id := AP_VALID_PKG_03.get_VendorID_03(i.vendor_number);
             
             if nvl(l_vendor_id,0) = 0 then
                FND_FILE.PUT_LINE(FND_FILE.LOG,'Vendor Number does not exist'||i.vendor_number);
                l_error_flag :=1;
                dbms_output.put_line('vendor');
             end if;
             -- Validate and get Agent ID
             l_agent_id := AP_VALID_PKG_03.get_EmployeeId_03(i.agent_number);
             dbms_output.put_line('agent Id'||l_agent_id);
             if nvl(l_agent_id,0) = 0 then
                    FND_FILE.PUT_LINE(FND_FILE.LOG,'Agent Number does not exist'||i.agent_number);
                    l_error_flag :=1;
                    dbms_output.put_line('Vendor Id');
             end if;
             dbms_output.put_line(l_error_flag);
fnd_file.put_line(fnd_file.log,'Error Flag is :-'||l_error_flag);
      IF l_error_flag  = 0 THEN   
       fnd_file.put_line(fnd_file.log,'Inserting Data');
      INSERT INTO po_headers_interface (
                                          interface_header_id
                                        , batch_id
                                        , action
                                        , document_type_code
                                        , currency_code
                                        , agent_id
                                        , vendor_id
                                        , vendor_site_code
                                        , approval_status
                                        , ship_to_location
                                        , bill_to_location
                                        , org_id
                                        , created_by
                                        , creation_date
                                        , last_update_login
                                        , last_updated_by
                                        , last_update_date
                                        )
                                 VALUES ( ln_po_header_id
                                        , ln_batch_id
                                        , 'ORIGINAL'
                                        , 'STANDARD'
                                        , i.curr_code
                                        , l_agent_id
                                        , l_vendor_id                                       
                                        , AP_VALID_PKG_03.get_vendor_siteId_03(l_vendor_id) 
                                       -- ,i.bill_to_location
                                        , 'INCOMPLETE'
                                        , i.ship_to_location
                                        , i.Ship_to_location
                                        , gn_org_id
                                        , gn_user_id
                                        , SYSDATE
                                        , gn_user_id
                                        , gn_user_id
                                        , SYSDATE
                                        );
                                       
             END IF;
--====================================================================
       --  For loop for insersion of lines records in interface table
-- ====================================================================
FOR j IN cur_po_order_lines (
                                                       p_vendor_number        => i.vendor_number
                                                     , p_ship_to_location  => i.ship_to_location
                                                     , p_bill_to_location  => i.bill_to_location
                                                     )
       LOOP
         SELECT PO_LINES_INTERFACE_S.nextval
         INTO ln_po_line_id
         FROM DUAL;
         
         -- Validating Item Number 
       dbms_output.put_line(ln_po_line_id);
       BEGIN
            
               l_inventory_item_id :=  AP_VALID_PKG_03.get_inventory_itemId_03(j.inventory_item );
               if l_inventory_item_id= 999999 then
                    FND_FILE.PUT_LINE('FND_FILE.LOG','Item Number does not exist'||j.inventory_item);
                   l_error_flag :=1;
               end if;
            

       END;
         dbms_output.put_line(l_inventory_item_id);
dbms_output.put_line (ln_po_header_id||','|| ln_po_line_id||','||l_inventory_item_id||','||j.unit_of_measure||','|| j.unit_price||','||j.quantity||','||j.line_number||','||gn_user_id
                                        );
                                 counter := counter + 1;      
insert into po_lines_interface (
                                          interface_header_id
                                        , interface_line_id
                                        , line_type
                                        , item_id
                                        ,item
                                        , item_description
                                        , UOM_CODE
                                        , unit_price
                                        , quantity
                                        , need_by_date
                                        , line_num
                                        , organization_id
                                        , created_by
                                        , creation_date
                                        , last_update_login
                                        , last_updated_by
                                        , last_update_date
                                        )
                                 VALUES (
                                          ln_po_header_id
                                        , ln_po_line_id
                                        , 'Goods'
                                        , l_inventory_item_id
                                        , j.inventory_item
                                        , AP_VALID_PKG_03.get_inventory_itemDscr_03(j.inventory_item)
                                        , j.unit_of_measure
                                        , j.unit_price
                                        , j.quantity
                                        , TRUNC(SYSDATE) + 1
                                        , counter
                                        , gn_org_id
                                        , gn_user_id
                                        , SYSDATE
                                        , gn_user_id
                                        , gn_user_id
                                        , SYSDATE
                                        );
                             
                                        
       END LOOP;

        end loop;
        
        
        
  commit;    
   end main;
   procedure Validate_Currency_03(p_curr_code fnd_currencies.CURRENCY_CODE%Type,P_ret_txt OUT Number )
  is
    cursor vld_curr(x_cur_code varchar2) is
    select currency_code 
    from   fnd_currencies 
    where  currency_code=x_cur_code;
    l_curr_code fnd_currencies.CURRENCY_CODE%Type;
    begin
          open vld_curr(p_curr_code);
          fetch vld_curr into l_curr_code;
          if vld_curr%notfound then
             P_ret_txt := 2;
          else
             p_ret_txt := 1;
          end if;
          Close vld_curr;
    exception when too_many_rows then
              P_ret_txt := 2;
              when others then
              P_ret_txt := 2;
    end Validate_Currency_03;
    --
    function get_VendorID_03(p_vendor_num ap_suppliers.segment1%type )
    return number is
    cursor cur_vendor_id is
    select vendor_id 
    from   ap_suppliers 
    where  segment1 = p_vendor_num;
    l_vendor_id ap_suppliers.vendor_id%type;
    begin
    for i in cur_vendor_id  loop
        l_vendor_id := i.vendor_id;
    end loop;
    return(l_vendor_id);
    end get_VendorID_03;   
 function get_EmployeeId_03(p_agent_number per_all_people_f.employee_number%type) 
    return number is
    l_employee_id     per_all_people_f.person_id%type;
    begin
    SELECT person_id  into l_employee_id
    from   per_all_people_f 
    where  employee_number =p_agent_number
    and trunc(sysdate) between trunc(effective_start_date) and trunc(effective_end_date)
    and business_group_id = (select  business_group_id 
                             from    hr_operating_units 
                             where   organization_id=FND_PROFILE.VALUE('ORG_ID')
                             );
    return( l_employee_id);
    exception when no_data_found then
              return(0);
              when too_many_rows then
              return(0);
              when others then
              return(0);
    end get_EmployeeId_03;  
function get_inventory_itemId_03(p_inv_item mtl_system_items.segment1%type )
                           return number
is
l_inv_item_id mtl_system_items.inventory_item_id%type;
begin
select inventory_item_id 
       into
       l_inv_item_id 
from   mtl_system_items 
where  segment1        = p_inv_item
and    organization_id = FND_PROFILE.VALUE('ORG_ID');
return(l_inv_item_id );
exception when no_data_found then
          return(999999);
          when too_many_rows then
          return(999999);
          when others then
          return(99999);
end get_inventory_itemId_03;

function get_vendor_siteId_03(p_vendor_id ap_suppliers.vendor_id%type) 
return varchar2 is 
cursor cur_vendor_site is
      select vendor_site_code
      FROM   ap_supplier_sites_all a,ap_suppliers b
      where  a.vendor_id=b.vendor_id
      and    a.terms_id=b.terms_id
      and    a.vendor_id=p_vendor_id 
      and    a.org_id=FND_PROFILE.VALUE('ORG_ID');
l_vendor_site_code   ap_supplier_sites_all.vendor_site_code%type;
begin
open cur_vendor_site;
fetch cur_vendor_site into l_vendor_site_code;
if cur_vendor_site%notfound then
    l_vendor_site_code := 'X';
end if;
close cur_vendor_site;
return(l_vendor_site_code);
end get_vendor_siteId_03 ;


function get_inventory_itemDscr_03(p_inv_item mtl_system_items.segment1%type )
                           return varchar2
is
l_inv_item_dscr mtl_system_items.description%type;
begin
select description
       into
       l_inv_item_dscr
from   mtl_system_items
where  segment1        = p_inv_item
and    organization_id = FND_PROFILE.VALUE('ORG_ID');
return(l_inv_item_dscr );
exception when no_data_found then
          return('X');
          when too_many_rows then
          return('X');
          when others then
          return('X');
end get_inventory_itemDscr_03;
end AP_VALID_PKG_03;