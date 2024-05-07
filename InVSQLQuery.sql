declare @AccountId bigint = 24076
declare @InvoiceDate smalldatetime = '2024-05-06'
declare @LastInvoiceProductionDateTime smalldatetime = '2024-02-06 00:43:59.380'
declare @LastInvoiceDate smalldatetime = '2024-02-06'
declare @IncludePCN bigint = 0
declare @ServiceCharge bigint = 10
 
SELECT
    (
        select
            (
                select
                    (
                        SELECT s.Type,
                               s.AccountId,
                               s.PolicyTermId,
                               s.PolicyReference,
                               s.TransactionReference,
                               s.TransactionAmount,
                               s.ItemEffectiveDate 'TransactionEffectiveDate',
                               s.ReceivableTypeCode,
                               s.InvoiceAmount,
                               s.TransactionTypeCode
                        FROM
                        (
                            select AccountId,
                                   'CH' 'ReceivableTypeCode',
                                   '' 'PolicyTermId',
                                   'Z' 'PolicyReference',
                                   @ServiceCharge 'TransactionAmount',
                                   GETDATE() 'ItemEffectiveDate',
                                   @ServiceCharge 'InvoiceAmount',
                                   '18-999999999999999999' 'TransactionReference',
                                   'Z' 'Type',
                                   'S' 'TransactionTypeCode'
                            from DC_BIL_Account
                            where AccountId = @AccountId
                                  and @ServiceCharge > 0
                        ) S
                            join DC_BIL_Account ac
                                on ac.AccountId = s.AccountId
                        where ac.AccountId = @AccountId
                        FOR XML RAW('CurrentLineItem'), TYPE
                    )
            ),
            (
                SELECT
                    (
                        SELECT s.Type,
                               s.AccountId,
                               s.PolicyTermId,
                               s.PolicyReference,
                               s.TransactionReference,
                               s.TransactionAmount,
                               s.ItemEffectiveDate 'TransactionEffectiveDate',
                               s.ReceivableTypeCode,
                               s.InvoiceAmount,
                               s.Description
                        FROM
                        (
                            SELECT distinct
                                item.AccountId,
                                item.PolicyTermId,
                                term.PolicyReference,
                                item.itemid,
                                item.TransactionDate,
                                bi.ItemScheduleId,
                                'IS' Type,
                                bi.InvoiceStatus,
                                item.OriginalTransactionAmount TransactionAmount,
                                item.ItemEffectiveDate,
                                item.ReceivableTypeCode,
                                item.TransactionTypeCode,
                                item.TransactionReference,
                                sum(bi.ItemScheduleAmount - bi.ItemRedistributedAmount) InvoiceAmount,
                                0 CashApplied,
                                0 CreditsApplied,
                                sum(bi.ItemWrittenOffAmount) WrittenOff,
                                sum(bi.ItemRedistributedAmount) RedistAmt,
                                term.PolicyTermStatusCode,
                                bi.InstallmentDate,
                                (
                                    SELECT sum(bis.ItemScheduleAmount - bis.ItemClosedToCashAmount
                                               - bis.ItemWrittenOffAmount - bis.ItemClosedToCreditAmount
                                               - bis.ItemRedistributedAmount
                                              )
                                    FROM DC_BIL_BillItemSchedule bis
                                    WHERE bis.ItemId = item.ItemId
                                ) Balance,
                                (
                                    select top 1
                                        Description
                                    from PSI_BIL_Support_CodeLists
                                    where Code in (
                                                      select top 1
                                                          TransactionTypeCode
                                                      from DC_BIL_BillItemSchedule bis
                                                      where bis.ItemId = item.ItemId
                                                  )
                                ) 'Description'
                            FROM DC_BIL_BillItemSchedule bi
                                inner join DC_BIL_BillItem item
                                    on bi.ItemId = item.ItemId
                                       AND item.AccountId = @AccountId
                                inner join DC_BIL_PolicyTerm term
                                    on term.PolicyTermId = item.PolicyTermId
                            WHERE bi.AccountId = @AccountId
                                  AND bi.InstallmentDate > @LastInvoiceDate
                                  AND @InvoiceDate >= bi.InstallmentDate
                                  AND bi.InstallmentTypeCode != 'M'
                                  AND (
                                          @IncludePCN = 1
                                          OR (
                                                 @IncludePCN = 0
                                                 AND PolicyTermStatusCode != N'PC'
                                             )
                                      )
                                  AND term.HoldTypeCode != N'HB'
                                  AND bi.FirstInvoiceId is null
                            group by item.AccountId,
                                     item.PolicyTermId,
                                     term.PolicyReference,
                                     item.ReceivableTypeCode,
                                     item.itemid,
                                     item.TransactionDate,
                                     bi.ItemScheduleId,
                                     bi.InvoiceStatus,
                                     item.OriginalTransactionAmount,
                                     item.ItemEffectiveDate,
                                     item.TransactionTypeCode,
                                     term.PolicyTermStatusCode,
                                     bi.InstallmentDate,
                                     item.TransactionReference
                            union all
                            SELECT item.AccountId,
                                   item.PolicyTermId,
                                   term.PolicyReference,
                                   item.itemid,
                                   item.TransactionDate,
                                   bi.ItemScheduleId,
                                   'IS' Type,
                                   bi.InvoiceStatus,
                                   item.OriginalTransactionAmount TransactionAmount,
                                   item.ItemEffectiveDate,
                                   item.ReceivableTypeCode,
                                   item.TransactionTypeCode,
                                   item.TransactionReference,
                                   sum(bi.ItemScheduleAmount - bi.ItemRedistributedAmount) InvoiceAmount,
                                   0 CashApplied,
                                   0 CreditsApplied,
                                   sum(bi.ItemWrittenOffAmount) WrittenOff,
                                   sum(bi.ItemRedistributedAmount) RedistAmt,
                                   term.PolicyTermStatusCode,
                                   bi.InstallmentDate,
                                   (
                                       SELECT sum(bis.ItemScheduleAmount - bis.ItemClosedToCashAmount
                                                  - bis.ItemWrittenOffAmount - bis.ItemClosedToCreditAmount
                                                  - bis.ItemRedistributedAmount
                                                 )
                                       FROM DC_BIL_BillItemSchedule bis
                                       WHERE bis.ItemId = item.ItemId
                                   ) Balance,
                                   (
                                       select top 1
                                           Description
                                       from PSI_BIL_Support_CodeLists
                                       where Code in (
                                                         select top 1
                                                             TransactionTypeCode
                                                         from DC_BIL_BillItemSchedule bis
                                                         where bis.ItemId = item.ItemId
                                                     )
                                   ) 'Description'
                            FROM DC_BIL_BillItemSchedule bi
                                inner join DC_BIL_BillItem item
                                    on bi.ItemId = item.ItemId
                                       AND item.AccountId = @AccountId
                                inner join DC_BIL_PolicyTerm term
                                    on term.PolicyTermId = item.PolicyTermId
                            WHERE bi.AccountId = @AccountId
                                  and item.PostedTimestamp > @LastInvoiceProductionDateTime
                                  and @LastInvoiceDate >= bi.InstallmentDate
                                  and item.ItemAmount > 0
                                  and bi.InstallmentTypeCode != 'M'
                            group by item.AccountId,
                                     item.PolicyTermId,
                                     term.PolicyReference,
                                     item.ReceivableTypeCode,
                                     item.itemid,
                                     item.TransactionDate,
                                     bi.ItemScheduleId,
                                     bi.InvoiceStatus,
                                     item.OriginalTransactionAmount,
                                     item.ItemEffectiveDate,
                                     item.TransactionTypeCode,
                                     term.PolicyTermStatusCode,
                                     bi.InstallmentDate,
                                     item.TransactionReference
                            UNION ALL
                            SELECT item.AccountId,
                                   item.PolicyTermId,
                                   term.PolicyReference,
                                   item.itemid,
                                   item.TransactionDate,
                                   bi.ItemScheduleId,
                                   'IS' Type,
                                   bi.InvoiceStatus,
                                   item.OriginalTransactionAmount TransactionAmount,
                                   item.ItemEffectiveDate,
                                   item.ReceivableTypeCode,
                                   item.TransactionTypeCode,
                                   item.TransactionReference,
                                   sum(bi.ItemScheduleAmount - bi.ItemRedistributedAmount) - isnull(tf.Amount, 0)
                                   - isnull(reversal.Amount, 0) InvoiceAmount,
                                   0 CashApplied,
                                   0 CreditsApplied,
                                   sum(bi.ItemWrittenOffAmount) WrittenOff,
                                   sum(bi.ItemRedistributedAmount) RedistAmt,
                                   term.PolicyTermStatusCode,
                                   bi.InstallmentDate,
                                   (
                                       SELECT sum(bis.ItemScheduleAmount - bis.ItemClosedToCashAmount
                                                  - bis.ItemWrittenOffAmount - bis.ItemClosedToCreditAmount
                                                  - bis.ItemRedistributedAmount
                                                 )
                                       FROM DC_BIL_BillItemSchedule bis
                                       WHERE bis.ItemId = item.ItemId
                                   ) Balance,
                                   (
                                       select top 1
                                           Description
                                       from PSI_BIL_Support_CodeLists
                                       where Code in (
                                                         select top 1
                                                             TransactionTypeCode
                                                         from DC_BIL_BillItemSchedule bis
                                                         where bis.ItemId = item.ItemId
                                                     )
                                   ) 'Description'
                            FROM DC_BIL_BillItemSchedule bi
                                inner join DC_BIL_BillItem item
                                    on bi.ItemId = item.ItemId
                                       AND item.AccountId = @AccountId
                                inner join DC_BIL_PolicyTerm term
                                    on term.PolicyTermId = item.PolicyTermId
                                left join
                                (
                                    SELECT DestinationId,
                                           sum(Amount) Amount
                                    FROM DC_BIL_PaymentAllocation
                                    WHERE PaymentAllocationId in (
                                                                     SELECT distinct
                                                                         TransferredFromAllocationId
                                                                     FROM DC_BIL_PaymentAllocation
                                                                     WHERE AccountId = @AccountId
                                                                           AND ExpirationDateTime >= @LastInvoiceDate
                                                                           and @InvoiceDate > ExpirationDateTime
                                                                           and ExpirationReasonCode = 'TROU'
                                                                 )
                                          AND AllocationTypeCode = 'IS'
                                    group by DestinationId
                                ) tf
                                    on tf.DestinationId = bi.ItemScheduleId
                                left join
                                (
                                    SELECT destinationid,
                                           sum(Amount) Amount
                                    FROM DC_BIL_PaymentAllocation
                                    WHERE PaymentId in (
                                                           SELECT PaymentId
                                                           FROM DC_BIL_PaymentReversal
                                                           WHERE PaymentId in (
                                                                                  SELECT DISTINCT
                                                                                      PaymentId
                                                                                  FROM DC_BIL_Payment
                                                                                  WHERE InitialAllocationAccountId = @AccountId
                                                                              )
                                                                 AND CreatedTimestamp >= @LastInvoiceDate
                                                                 AND @InvoiceDate > CreatedTimestamp
                                                       )
                                          AND TransactionGUID in (
                                                                     SELECT TransactionGUID
                                                                     FROM DC_BIL_PaymentReversal
                                                                     WHERE PaymentId in (
                                                                                            SELECT DISTINCT
                                                                                                PaymentId
                                                                                            FROM DC_BIL_Payment
                                                                                            WHERE InitialAllocationAccountId = @AccountId
                                                                                        )
                                                                           AND CreatedTimestamp >= @LastInvoiceDate
                                                                           AND @InvoiceDate > CreatedTimestamp
                                                                 )
                                    group by DestinationId
                                ) reversal
                                    on reversal.DestinationId = bi.ItemScheduleId
                            WHERE bi.AccountId = @AccountId
                                  AND @LastInvoiceDate >= bi.InstallmentDate
                                  AND bi.InstallmentTypeCode != 'M'
                                  AND bi.ItemClosedIndicator = 'N'
                                  AND bi.FirstInvoiceId IS NULL
                                  AND term.PolicyTermStatusCode != N'PC'
                                  AND bi.TransactionTypeCode != 'REIN'
                                  AND term.HoldTypeCode != 'HB'
                                  AND bi.InvoiceStatus != 'R'
                            group by item.AccountId,
                                     item.PolicyTermId,
                                     term.PolicyReference,
                                     item.ReceivableTypeCode,
                                     item.itemid,
                                     item.TransactionDate,
                                     bi.ItemScheduleId,
                                     bi.InvoiceStatus,
                                     item.OriginalTransactionAmount,
                                     item.ItemEffectiveDate,
                                     item.TransactionTypeCode,
                                     term.PolicyTermStatusCode,
                                     bi.InstallmentDate,
                                     tf.Amount,
                                     reversal.Amount,
                                     item.TransactionReference
                            UNION ALL
                            SELECT item.AccountId,
                                   item.PolicyTermId,
                                   term.PolicyReference,
                                   item.itemid,
                                   item.TransactionDate,
                                   bi.ItemScheduleId,
                                   'IS' Type,
                                   bi.InvoiceStatus,
                                   item.OriginalTransactionAmount TransactionAmount,
                                   item.ItemEffectiveDate,
                                   item.ReceivableTypeCode,
                                   item.TransactionTypeCode,
                                   item.TransactionReference,
                                   sum(bi.ItemScheduleAmount - bi.ItemRedistributedAmount) InvoiceAmount,
                                   0 CashApplied,
                                   0 CreditsApplied,
                                   sum(bi.ItemWrittenOffAmount) WrittenOff,
                                   sum(bi.ItemRedistributedAmount) RedistAmt,
                                   term.PolicyTermStatusCode,
                                   bi.InstallmentDate,
                                   (
                                       SELECT sum(bis.ItemScheduleAmount - bis.ItemClosedToCashAmount
                                                  - bis.ItemWrittenOffAmount - bis.ItemClosedToCreditAmount
                                                  - bis.ItemRedistributedAmount
                                                 )
                                       FROM DC_BIL_BillItemSchedule bis
                                       WHERE bis.ItemId = item.ItemId
                                   ) Balance,
                                   (
                                       select top 1
                                           Description
                                       from PSI_BIL_Support_CodeLists
                                       where Code in (
                                                         select top 1
                                                             TransactionTypeCode
                                                         from DC_BIL_BillItemSchedule bis
                                                         where bis.ItemId = item.ItemId
                                                     )
                                   ) 'Description'
                            FROM DC_BIL_BillItemSchedule bi
                                inner join DC_BIL_BillItem item
                                    on bi.ItemId = item.ItemId
                                       AND item.AccountId = @AccountId
                                inner join DC_BIL_PolicyTerm term
                                    on term.PolicyTermId = item.PolicyTermId
                            WHERE bi.AccountId = @AccountId
                                  AND bi.InstallmentTypeCode != 'M'
                                  AND bi.InstallmentDate > @InvoiceDate
                                  AND term.PolicyTermStatusCode IN ( N'CNP', N'CN' )
                                  AND bi.FirstInvoiceId IS NULL
                                  AND term.HoldTypeCode != 'HB'
                            group by item.AccountId,
                                     item.PolicyTermId,
                                     term.PolicyReference,
                                     item.ReceivableTypeCode,
                                     item.itemid,
                                     item.TransactionDate,
                                     bi.ItemScheduleId,
                                     bi.InvoiceStatus,
                                     item.OriginalTransactionAmount,
                                     item.ItemEffectiveDate,
                                     item.TransactionTypeCode,
                                     term.PolicyTermStatusCode,
                                     bi.InstallmentDate,
                                     item.TransactionReference
                            having sum(bi.ItemScheduleAmount - bi.ItemRedistributedAmount - bi.ItemClosedToCashAmount
                                       - bi.ItemWrittenOffAmount - bi.ItemClosedToCreditAmount
                                      ) > 0
                            UNION ALL
                            SELECT item.AccountId,
                                   item.PolicyTermId,
                                   term.PolicyReference,
                                   item.itemid,
                                   item.TransactionDate,
                                   bis.itemscheduleid,
                                   'CR' Type,
                                   bis.InvoiceStatus,
                                   item.OriginalTransactionAmount TransactionAmount,
                                   item.ItemEffectiveDate,
                                   item.ReceivableTypeCode,
                                   item.TransactionTypeCode,
                                   item.TransactionReference,
                                   -sum(ca.Amount) InvoiceAmount,
                                   0 CashApplied,
                                   0 CreditsApplied,
                                   0 WrittenOff,
                                   0 RedistAmt,
                                   term.PolicyTermStatusCode,
                                   bis.InstallmentDate,
                                   0 Balance,
                                   (
                                       select top 1
                                           Description
                                       from PSI_BIL_Support_CodeLists
                                       where Code in (
                                                         select top 1
                                                             TransactionTypeCode
                                                         from DC_BIL_BillItem bis
                                                         where bis.ItemId = item.ItemId
                                                     )
                                   ) 'Description'
                            FROM DC_BIL_BillItem item
                                inner join DC_BIL_CreditAllocation ca
                                    on ca.ItemId = item.ItemId
                                inner join DC_BIL_BillItemSchedule bis
                                    on bis.ItemScheduleId = ca.DestinationId
                                inner join DC_BIL_PolicyTerm term
                                    on term.PolicyTermId = bis.PolicyTermId
                            WHERE ca.AccountId = @AccountId
                                  and ca.AllocationStatusIndicator = 'A'
                                  and item.PostedTimestamp >= @LastInvoiceDate
                                  and bis.InstallmentDate > @LastInvoiceDate
                                  and @InvoiceDate >= bis.InstallmentDate
                                  AND (
                                          @IncludePCN = 1
                                          OR (
                                                 @IncludePCN = 0
                                                 AND PolicyTermStatusCode != N'PC'
                                             )
                                      )
                                  AND term.HoldTypeCode != N'HB'
                                  and bis.FirstInvoiceId is NULL
                            group by item.AccountId,
                                     item.PolicyTermId,
                                     term.PolicyReference,
                                     item.ReceivableTypeCode,
                                     item.itemid,
                                     item.TransactionDate,
                                     bis.ItemScheduleId,
                                     bis.InvoiceStatus,
                                     item.OriginalTransactionAmount,
                                     item.ItemEffectiveDate,
                                     item.TransactionTypeCode,
                                     term.PolicyTermStatusCode,
                                     bis.InstallmentDate,
                                     item.TransactionReference
                            UNION ALL
                            select item.AccountId,
                                   item.PolicyTermId,
                                   term.PolicyReference,
                                   item.itemid,
                                   item.TransactionDate,
                                   bis.itemscheduleid,
                                   'CR' Type,
                                   bis.InvoiceStatus,
                                   item.OriginalTransactionAmount TransactionAmount,
                                   item.ItemEffectiveDate,
                                   item.ReceivableTypeCode,
                                   item.TransactionTypeCode,
                                   item.TransactionReference,
                                   -sum(ca.Amount) InvoiceAmount,
                                   0 CashApplied,
                                   0 CreditsApplied,
                                   0 WrittenOff,
                                   0 RedistAmt,
                                   term.PolicyTermStatusCode,
                                   bis.InstallmentDate,
                                   0 Balance,
                                   (
                                       select top 1
                                           Description
                                       from PSI_BIL_Support_CodeLists
                                       where Code in (
                                                         select top 1
                                                             TransactionTypeCode
                                                         from DC_BIL_BillItem bis
                                                         where bis.ItemId = item.ItemId
                                                     )
                                   ) 'Description'
                            from DC_BIL_BillItem item
                                inner join DC_BIL_CreditAllocation ca
                                    on ca.ItemId = item.ItemId
                                inner join DC_BIL_BillItemSchedule bis
                                    on bis.ItemScheduleId = ca.DestinationId
                                inner join DC_BIL_PolicyTerm term
                                    on term.PolicyTermId = bis.PolicyTermId
                            where ca.AccountId = @AccountId
                                  and ca.AllocationStatusIndicator = 'A'
                                  and bis.InstallmentDate > @InvoiceDate
                                  AND bis.ItemClosedIndicator = 'N'
                                  and bis.FirstInvoiceId is null
                                  AND term.PolicyTermStatusCode IN ( N'CNP', N'CN' )
                                  AND term.HoldTypeCode != 'HB'
                            group by item.AccountId,
                                     item.PolicyTermId,
                                     term.PolicyReference,
                                     item.ReceivableTypeCode,
                                     item.itemid,
                                     item.TransactionDate,
                                     bis.ItemScheduleId,
                                     bis.InvoiceStatus,
                                     item.OriginalTransactionAmount,
                                     item.ItemEffectiveDate,
                                     item.TransactionTypeCode,
                                     term.PolicyTermStatusCode,
                                     bis.InstallmentDate,
                                     item.TransactionReference
                            union all
                            select item.AccountId,
                                   item.PolicyTermId,
                                   term.PolicyReference,
                                   item.itemid,
                                   item.TransactionDate,
                                   bis.itemscheduleid,
                                   'CR' Type,
                                   bis.InvoiceStatus,
                                   item.OriginalTransactionAmount TransactionAmount,
                                   item.ItemEffectiveDate,
                                   item.ReceivableTypeCode,
                                   item.TransactionTypeCode,
                                   item.TransactionReference,
                                   -sum(ca.Amount) InvoiceAmount,
                                   0 CashApplied,
                                   0 CreditsApplied,
                                   0 WrittenOff,
                                   0 RedistAmt,
                                   term.PolicyTermStatusCode,
                                   bis.InstallmentDate,
                                   0 Balance,
                                   (
                                       select top 1
                                           Description
                                       from PSI_BIL_Support_CodeLists
                                       where Code in (
                                                         select top 1
                                                             TransactionTypeCode
                                                         from DC_BIL_BillItem bis
                                                         where bis.ItemId = item.ItemId
                                                     )
                                   ) 'Description'
                            from DC_BIL_BillItem item
                                inner join DC_BIL_CreditAllocation ca
                                    on ca.ItemId = item.ItemId
                                inner join DC_BIL_BillItemSchedule bis
                                    on bis.ItemScheduleId = ca.DestinationId
                                inner join DC_BIL_PolicyTerm term
                                    on term.PolicyTermId = bis.PolicyTermId
                            where ca.AccountId = @AccountId
                                  and ca.AllocationStatusIndicator = 'A'
                                  AND @LastInvoiceDate > item.PostedTimestamp
                                  AND bis.InstallmentDate > @LastInvoiceDate
                                  AND @InvoiceDate >= bis.InstallmentDate
                                  AND (
                                          @IncludePCN = 1
                                          OR (
                                                 @IncludePCN = 0
                                                 AND PolicyTermStatusCode != N'PC'
                                             )
                                      )
                                  AND term.HoldTypeCode != N'HB'
                                  AND bis.FirstInvoiceId is null
                            group by item.AccountId,
                                     item.PolicyTermId,
                                     term.PolicyReference,
                                     item.ReceivableTypeCode,
                                     item.itemid,
                                     item.TransactionDate,
                                     bis.ItemScheduleId,
                                     bis.InvoiceStatus,
                                     item.OriginalTransactionAmount,
                                     item.ItemEffectiveDate,
                                     item.TransactionTypeCode,
                                     term.PolicyTermStatusCode,
                                     bis.InstallmentDate,
                                     item.TransactionReference
                            union all
                            select item.AccountId,
                                   item.PolicyTermId,
                                   term.PolicyReference,
                                   item.itemid,
                                   item.TransactionDate,
                                   bis.itemscheduleid,
                                   'CR' Type,
                                   bis.InvoiceStatus,
                                   item.OriginalTransactionAmount TransactionAmount,
                                   item.ItemEffectiveDate,
                                   item.ReceivableTypeCode,
                                   item.TransactionTypeCode,
                                   item.TransactionReference,
                                   -sum(ca.Amount) InvoiceAmount,
                                   0 CashApplied,
                                   0 CreditsApplied,
                                   0 WrittenOff,
                                   0 RedistAmt,
                                   term.PolicyTermStatusCode,
                                   bis.InstallmentDate,
                                   0 Balance,
                                   (
                                       select top 1
                                           Description
                                       from PSI_BIL_Support_CodeLists
                                       where Code in (
                                                         select top 1
                                                             TransactionTypeCode
                                                         from DC_BIL_BillItem bis
                                                         where bis.ItemId = item.ItemId
                                                     )
                                   ) 'Description'
                            from DC_BIL_BillItem item
                                inner join DC_BIL_CreditAllocation ca
                                    on ca.ItemId = item.ItemId
                                inner join DC_BIL_BillItemSchedule bis
                                    on bis.ItemScheduleId = ca.DestinationId
                                inner join DC_BIL_PolicyTerm term
                                    on term.PolicyTermId = bis.PolicyTermId
                            where ca.AccountId = @AccountId
                                  and ca.AllocationStatusIndicator = 'A'
                                  and @LastInvoiceDate > item.PostedTimestamp
                                  and bis.InstallmentDate = @LastInvoiceDate
                                  AND term.policyTermStatusCode != N'PC'
                                  AND term.HoldTypeCode != N'HB'
                                  AND bis.ItemClosedIndicator = 'N'
                                  and bis.InvoiceStatus = 'N'
                                  AND bis.TransactionTypeCode != 'REIN'
                            group by item.AccountId,
                                     item.PolicyTermId,
                                     term.PolicyReference,
                                     item.ReceivableTypeCode,
                                     item.itemid,
                                     item.TransactionDate,
                                     bis.ItemScheduleId,
                                     bis.InvoiceStatus,
                                     item.OriginalTransactionAmount,
                                     item.ItemEffectiveDate,
                                     item.TransactionTypeCode,
                                     term.PolicyTermStatusCode,
                                     bis.InstallmentDate,
                                     item.TransactionReference
                            UNION ALL
                            SELECT item.AccountId,
                                   item.PolicyTermId,
                                   term.PolicyReference,
                                   wo.ReceivableWriteOffId 'itemId',
                                   wo.WriteOffRequestDate 'TransactionDate',
                                   bis.ItemScheduleId,
                                   'WO' 'Type',
                                   bis.InvoiceStatus,
                                   -sum(OriginalWriteOffAmount) 'TransactionAmount',
                                   WriteOffRequestDate 'ItemEffectiveDate',
                                   item.ReceivableTypeCode,
                                   wo.WriteOffTypeCode 'TransactionTypeCode',
                                   '' 'TransactionReference',
                                   -sum(OriginalWriteOffAmount) 'InvoiceAmount',
                                   0 'CashApplied',
                                   0 'CreditsApplied',
                                   0 'WrittenOff',
                                   0 'RedistAmt',
                                   term.PolicyTermStatusCode,
                                   bis.InstallmentDate,
                                   -sum(OriginalWriteOffAmount) 'Balance',
                                   (
                                       select top 1
                                           Description
                                       from PSI_BIL_Support_CodeLists
                                       where Code in ( 'WO' )
                                   ) 'Description'
                            FROM DC_BIL_BillItemSchedule bis
                                inner join DC_BIL_BillItem item
                                    on item.ItemId = bis.ItemId
                                inner join DC_BIL_PolicyTerm term
                                    on term.PolicyTermId = item.PolicyTermId
                                inner join DC_BIL_ReceivableWriteOff wo
                                    on bis.ItemScheduleId = wo.ReceivableSourceId
                            WHERE item.AccountId = @AccountId
                                  and (CASE
                                           WHEN ISNULL(bis.PolicyTermId, 0) != 0 THEN
                                               'IS'
                                           ELSE
                                               'CH'
                                       END
                                      ) = wo.ReceivableSourceTypeCode
                                  AND (
                                          @IncludePCN = 1
                                          OR (
                                                 @IncludePCN = 0
                                                 AND PolicyTermStatusCode != N'PC'
                                             )
                                      )
                                  AND term.HoldTypeCode != N'HB'
                                  AND bis.InstallmentDate > @LastInvoiceDate
                                  and @InvoiceDate >= bis.InstallmentDate
                                  AND bis.FirstInvoiceId IS NULL
                            GROUP BY item.AccountId,
                                     item.PolicyTermId,
                                     term.PolicyReference,
                                     item.ReceivableTypeCode,
                                     wo.ReceivableWriteOffId,
                                     wo.WriteOffTypeCode,
                                     wo.WriteOffRequestDate,
                                     bis.ItemScheduleId,
                                     bis.InvoiceStatus,
                                     item.OriginalTransactionAmount,
                                     item.TransactionTypeCode,
                                     term.PolicyTermStatusCode,
                                     bis.InstallmentDate,
                                     WriteOffRequestDate
                            union all
                            SELECT item.AccountId,
                                   item.PolicyTermId,
                                   term.PolicyReference,
                                   wr.ReceivableWriteOffReversalId,
                                   cast(wr.ReversalDate as date) 'TransactionDate',
                                   bis.ItemScheduleId,
                                   'WR' 'Type',
                                   bis.InvoiceStatus,
                                   sum(wr.ReversalAmount) 'TransactionAmount',
                                   WriteOffRequestDate 'ItemEffectiveDate',
                                   item.ReceivableTypeCode,
                                   CASE
                                       WHEN writeofftypecode = 'WO' THEN
                                           'WOR'
                                       WHEN writeofftypecode = 'WA' THEN
                                           'WAR'
                                   END,
                                   '' 'TransactionReference',
                                   sum(wr.ReversalAmount) 'InvoiceAmount',
                                   0 'CashApplied',
                                   0 'CreditsApplied',
                                   0 'WrittenOff',
                                   0 'RedistAmt',
                                   term.PolicyTermStatusCode,
                                   bis.InstallmentDate,
                                   sum(wr.ReversalAmount) 'Balance',
                                   (
                                       select top 1
                                           Description
                                       from PSI_BIL_Support_CodeLists
                                       where Code in (
                                                         select top 1
                                                             TransactionTypeCode
                                                         from DC_BIL_BillItemSchedule bis
                                                         where bis.ItemScheduleId = bis.ItemScheduleId
                                                     )
                                   ) 'Description'
                            FROM DC_BIL_BillItemSchedule bis
                                inner join DC_BIL_BillItem item
                                    on item.ItemId = bis.ItemId
                                inner join DC_BIL_ReceivableWriteOff wo
                                    on bis.ItemScheduleId = wo.ReceivableSourceId
                                inner join DC_BIL_PolicyTerm term
                                    on term.PolicyTermId = wo.PolicyTermId
                                inner join DC_BIL_ReceivableWriteOffReversal wr
                                    on wo.ReceivableWriteOffId = wr.ReceivableWriteOffId
                                       and ReceivableSourceTypeCode = 'IS'
                            WHERE item.AccountId = @AccountId
                                  and (CASE
                                           WHEN ISNULL(bis.PolicyTermId, 0) != 0 THEN
                                               'IS'
                                           ELSE
                                               'CH'
                                       END
                                      ) = wo.ReceivableSourceTypeCode
                            GROUP BY item.AccountId,
                                     item.PolicyTermId,
                                     term.PolicyReference,
                                     item.ReceivableTypeCode,
                                     writeofftypecode,
                                     wr.ReceivableWriteOffReversalId,
                                     cast(wr.ReversalDate as date),
                                     bis.ItemScheduleId,
                                     bis.InvoiceStatus,
                                     item.OriginalTransactionAmount,
                                     item.TransactionTypeCode,
                                     term.PolicyTermStatusCode,
                                     bis.InstallmentDate,
                                     WriteOffRequestDate
                            union all
                            SELECT ch.AccountId,
                                   0 as 'PolicyTermId',
                                   'Z' 'PolicyReference',
                                   wo.ReceivableWriteOffId 'itemid',
                                   wo.WriteOffRequestDate 'TransactionDate',
                                   ch.ChargeId 'ItemScheduleId',
                                   'WO' 'Type',
                                   ch.InvoiceStatus,
                                   -sum(OriginalWriteOffAmount) 'TransactionAmount',
                                   NULL 'ItemEffectiveDate',
                                   'CH' 'ReceivableTypeCode',
                                   wo.writeofftypecode 'TransactionTypeCode',
                                   '' 'TransactionReference',
                                   -sum(OriginalWriteOffAmount) 'InvoiceAmount',
                                   0 'CashApplied',
                                   0 'CreditsApplied',
                                   0 'WrittenOff',
                                   0 'RedistAmt',
                                   '' 'PolicyTermStatusCode',
                                   ch.InstallmentDate,
                                   -sum(OriginalWriteOffAmount) 'Balance',
                                   'Charge' 'Description'
                            FROM DC_BIL_Charges ch
                                inner join DC_BIL_ReceivableWriteOff wo
                                    on ch.ChargeId = wo.ReceivableSourceId
                                       and wo.ReceivableSourceTypeCode = 'CH'
                            WHERE ch.AccountId = @AccountId
                                  and ch.InstallmentDate > @LastInvoiceDate
                                  and @InvoiceDate >= ch.InstallmentDate
                            GROUP BY ch.AccountId,
                                     wo.ReceivableWriteOffId,
                                     ch.ChargeId,
                                     wo.WriteOffRequestDate,
                                     ch.InvoiceStatus,
                                     ch.ChargeAmount,
                                     ch.ChargeTypeCode,
                                     wo.WriteOffTypeCode,
                                     ch.InstallmentDate
                            union all
                            SELECT wo.AccountId,
                                   0 as 'PolicyTermId',
                                   'Z' 'PolicyReference',
                                   wr.ReceivableWriteOffReversalId 'itemId',
                                   cast(wr.ReversalDate as date) 'TransactionDate',
                                   ch.ChargeId 'itemScheduleId',
                                   'WR' 'Type',
                                   ch.InvoiceStatus,
                                   sum(wr.ReversalAmount) 'TransactionAmount',
                                   NULL 'ItemEffectiveDate',
                                   'CH' 'ReceivableTypeCode',
                                   CASE
                                       WHEN writeofftypecode = 'WO' THEN
                                           'WOR'
                                       WHEN writeofftypecode = 'WA' THEN
                                           'WAR'
                                   End 'TransactionTypeCode',
                                   '' 'TransactionReference',
                                   sum(wr.ReversalAmount) 'InvoiceAmount',
                                   0 'CashApplied',
                                   0 'CreditsApplied',
                                   0 'WrittenOff',
                                   0 'RedistAmt',
                                   '' 'PolicyTermStatusCode',
                                   ch.InstallmentDate,
                                   sum(wr.ReversalAmount) 'Balance',
                                   'Charge' 'Description'
                            FROM DC_BIL_Charges ch
                                inner join DC_BIL_ReceivableWriteOff wo
                                    on ch.ChargeId = wo.ReceivableSourceId
                                       and wo.ReceivableSourceTypeCode = 'CH'
                                inner join DC_BIL_ReceivableWriteOffReversal wr
                                    on wo.ReceivableWriteOffId = wr.ReceivableWriteOffId
                                       and wo.ReceivableSourceTypeCode = 'CH'
                            WHERE ch.AccountId = @AccountId
                            GROUP BY wo.AccountId,
                                     wr.ReceivableWriteOffReversalId,
                                     cast(wr.ReversalDate as date),
                                     ch.ChargeId,
                                     ch.InvoiceStatus,
                                     ch.ChargeTypeCode,
                                     wo.WriteOffTypeCode,
                                     ch.InstallmentDate
                        ) S
                            join DC_BIL_Account ac
                                on ac.AccountId = s.AccountId
                        where ac.AccountId = @AccountId
                        FOR XML RAW('CurrentLineItem'), TYPE
                    )
            )
        FOR XML RAW('CurrentLineItems'), TYPE
    )
FROM DC_BIL_Account ACC
WHERE acc.accountid = @AccountId
FOR XML PATH('InvoiceCurrentLineItems'), ROOT('InvoiceCurrentLineItemss'), ELEMENTS XSINIL, TYPE