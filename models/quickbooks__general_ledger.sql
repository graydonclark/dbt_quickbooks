with unioned_models as (

    {{ dbt_utils.union_relations(get_enabled_unioned_models()) }}
),

gl_union as (

    select transaction_id,
        source_relation,
        index,
        transaction_date,
        customer_id,
        vendor_id,
        amount,
        account_id,
        class_id,
        transaction_type,
        transaction_source 
    from unioned_models
),

accounts as (

    select *
    from {{ ref('int_quickbooks__account_classifications') }}
),


adjusted_gl as (
    
    select distinct
        {{ dbt_utils.generate_surrogate_key(['gl_union.transaction_id', 'gl_union.index', 'gl_union.account_id', ' gl_union.transaction_type', 'gl_union.transaction_source']) }} as unique_id,
        gl_union.transaction_id,
        gl_union.source_relation,
        gl_union.index as transaction_index,
        gl_union.transaction_date,
        gl_union.customer_id,
        gl_union.vendor_id,
        gl_union.amount,
        gl_union.account_id,
        gl_union.class_id,
        accounts.account_number,
        accounts.name as account_name,
        accounts.is_sub_account,
        accounts.parent_account_number,
        accounts.parent_account_name,
        accounts.account_type,
        accounts.account_sub_type,
        accounts.financial_statement_helper,
        accounts.balance as account_current_balance,
        accounts.classification as account_class, 
        gl_union.transaction_type,
        gl_union.transaction_source,
        accounts.transaction_type as account_transaction_type,
        case when accounts.transaction_type = gl_union.transaction_type
            then gl_union.amount
            else gl_union.amount * -1
                end as adjusted_amount
    from gl_union

    left join accounts
        on gl_union.account_id = accounts.account_id
        and gl_union.source_relation = accounts.source_relation
),

final as (

    select
        *,
        sum(adjusted_amount) over (partition by account_id order by transaction_date, account_id rows unbounded preceding) as running_balance
    from adjusted_gl
)

select *
from final
