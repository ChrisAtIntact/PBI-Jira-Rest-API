let
    GetPage = (query as record, optional nextToken as nullable text) as record =>
        let
            baseQuery    = if Record.HasFields(query, "maxResults") then query else Record.AddField(query, "maxResults", "100"),
            updatedQuery = if nextToken <> null then Record.AddField(baseQuery, "nextPageToken", nextToken) else baseQuery,
            AuthKey      = "Basic " & Binary.ToText(Text.ToBinary(JiraApiUser & ":" & JiraApiToken), BinaryEncoding.Base64),
            JsonData     = Json.Document(Web.Contents(JiraApiUrl, [
                Headers = [ Authorization = AuthKey, #"Content-Type" = "application/json" ],
                Query   = updatedQuery
            ]))
        in
            [
                issues    = JsonData[issues],
                nextToken = try JsonData[nextPageToken] otherwise null,
                isLast    = try JsonData[isLast] otherwise false
            ],
    // Parameter  accepts Jira API query options such as jql and fields as key-value pairs
    LoadAllIssues = (query as record) as table =>
        let
            Pages = List.Generate(
                ()=> GetPage(query, null),
                each _ <> null,
                each if [isLast] then null else GetPage(query, [nextToken]),
                each [issues]
            ),
            CombinedIssues     = List.Combine(Pages),
            BaseTable          = Table.FromList(CombinedIssues, Splitter.SplitByNothing(), {"Record"}, null, ExtraValues.Error),
            ExpandedKeyFields  = Table.ExpandRecordColumn(BaseTable, "Record", {"key", "fields"}),
            SampleFieldsRecord = if Table.RowCount(ExpandedKeyFields) > 0 then ExpandedKeyFields{0}[fields] else [],
            FieldNames         = try Record.FieldNames(SampleFieldsRecord) otherwise {},
            ExpandedFields     = if List.Count(FieldNames) > 0
                                 then Table.ExpandRecordColumn(ExpandedKeyFields, "fields", FieldNames)
                                 else ExpandedKeyFields
        in
            ExpandedFields
in
    LoadAllIssues
