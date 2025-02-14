// ------------------------------------------------------------------------------------------------
// Copyright (c) Microsoft Corporation. All rights reserved.
// Licensed under the MIT License. See License.txt in the project root for license information.
// ------------------------------------------------------------------------------------------------

namespace System.Security.AccessControl;

using System.Reflection;

codeunit 9864 "Permission Impl."
{
    Access = Internal;
    InherentEntitlements = X;
    InherentPermissions = X;

    var
        AllObjTxt: Label 'All objects of type %1', Comment = '%1= type name, e.g. Table Data or Report or Page';
        AllObjExceptTxt: Label 'All objects of type %1 (except where otherwise stated)', Comment = '%1= type name, e.g. Table Data or Report or Page';
        SelectObjectsLbl: Label 'Select objects to add';
        SelectObjectLbl: Label 'Select object to add';
        PermissionAlreadyExistsWithDifferentTypeErr: Label 'The permission already exists with type %1', Comment = '%1 = the type of the existing permission';
        IncludeOption: Option " ",Yes,Indirect;
        IncludeDescriptionOption: Option "Specifies no permission","Specifies direct permission","Specifies indirect permission";
        ExcludeOption: Option " ",Exclude,"Reduce to indirect";
        ExcludeDescriptionOption: Option "No change to permission","Excludes any permission","Excludes any direct permission";
        PermissionUpdatedLbl: Label 'Tenant %1 permission for the App Id %2, Role %3, ObjectType %4, ObjectId %5  has been updated with the value: "%6", by the UserSecurityId %7.', Locked = true;
        MultiplePermissionsUpdatedLbl: Label 'The tenant permissions for the App Id %1, Role %2, ObjectType %3, ObjectId %4  have been updated with the following values - Read "%5", Insert "%6", Modify "%7" and Delete "%8" by the UserSecurityId %9.', Locked = true;

    procedure SelectPermissions(CurrAppId: Guid; CurrRoleID: Code[20]): Boolean
    var
        TempAllObjWithCaption: Record AllObjWithCaption temporary;
        Objects: Page Objects;
    begin
        SetupObjectsPage(SelectObjectsLbl, Objects, TempAllObjWithCaption);

        if Objects.RunModal() <> Action::LookupOK then
            exit(false);

        Clear(TempAllObjWithCaption);
        Objects.GetSelectedRecords(TempAllObjWithCaption);

        if TempAllObjWithCaption.FindSet() then
            repeat
                AddNewPermission(CurrAppId, CurrRoleID, TempAllObjWithCaption."Object Type", TempAllObjWithCaption."Object ID");
            until TempAllObjWithCaption.Next() = 0;

        exit(true);
    end;

    procedure LookupPermission(ObjectType: Option; var ObjectIDText: Text): Boolean
    var
        TempAllObjWithCaption: Record AllObjWithCaption temporary;
        Objects: Page Objects;
        ObjectID: Integer;
    begin
        TempAllObjWithCaption.SetRange("Object Type", ObjectType);
        TempAllObjWithCaption."Object Type" := ObjectType;
        if Evaluate(ObjectID, ObjectIDText) then
            TempAllObjWithCaption."Object ID" := ObjectID;

        SetupObjectsPage(SelectObjectLbl, Objects, TempAllObjWithCaption);

        if Objects.RunModal() <> Action::LookupOK then
            exit(false);

        Clear(TempAllObjWithCaption);
        Objects.GetRecord(TempAllObjWithCaption);

        ObjectIDText := Format(TempAllObjWithCaption."Object ID");
        exit(true);
    end;

    procedure UpdatePermissionLine(IsTypeChanged: Boolean; var TenantPermission: Record "Tenant Permission"; var ObjectCaption: Text; var ObjectName: Text; var ReadPermissionAsTxt: Text[50]; var InsertPermissionAsTxt: Text[50]; var ModifyPermissionAsTxt: Text[50]; var DeletePermissionAsTxt: Text[50]; var ExecutePermissionAsTxt: Text[50])
    begin
        GetObjectionCaptionAndName(TenantPermission, ObjectCaption, ObjectName);

        if IsTypeChanged then begin
            EmptyIrrelevantPermissionFields(TenantPermission);
            SetDefaultPermissionFields(TenantPermission);
        end;

        ReadPermissionAsTxt := GetPermissionAsTxt(TenantPermission.Type, TenantPermission."Read Permission");
        InsertPermissionAsTxt := GetPermissionAsTxt(TenantPermission.Type, TenantPermission."Insert Permission");
        ModifyPermissionAsTxt := GetPermissionAsTxt(TenantPermission.Type, TenantPermission."Modify Permission");
        DeletePermissionAsTxt := GetPermissionAsTxt(TenantPermission.Type, TenantPermission."Delete Permission");
        ExecutePermissionAsTxt := GetPermissionAsTxt(TenantPermission.Type, TenantPermission."Execute Permission");
    end;

    procedure UpdateSelectedPermissionLines(var TenantPermission: Record "Tenant Permission"; RIMDX: Text[1]; PermissionOption: Option)
    var
        ModifyPermissionLine: Boolean;
    begin
        if TenantPermission.FindSet() then
            repeat
                ModifyPermissionLine := false;
                case RIMDX of
                    'R':
                        if TenantPermission."Object Type" = TenantPermission."Object Type"::"Table Data" then
                            if TenantPermission."Read Permission" <> PermissionOption then begin
                                TenantPermission."Read Permission" := PermissionOption;
                                ModifyPermissionLine := true;
                                Session.LogAuditMessage(StrSubstNo(PermissionUpdatedLbl, RIMDX, TenantPermission."App ID", TenantPermission."Role ID", TenantPermission."Object Type", TenantPermission."Object ID",
                                    TenantPermission."Read Permission", UserSecurityId()), SecurityOperationResult::Success, AuditCategory::RoleManagement, 2, 0);
                            end;
                    'I':
                        if TenantPermission."Object Type" = TenantPermission."Object Type"::"Table Data" then
                            if TenantPermission."Insert Permission" <> PermissionOption then begin
                                TenantPermission."Insert Permission" := PermissionOption;
                                ModifyPermissionLine := true;
                                Session.LogAuditMessage(StrSubstNo(PermissionUpdatedLbl, RIMDX, TenantPermission."App ID", TenantPermission."Role ID", TenantPermission."Object Type", TenantPermission."Object ID",
                                    TenantPermission."Insert Permission", UserSecurityId()), SecurityOperationResult::Success, AuditCategory::RoleManagement, 2, 0);
                            end;
                    'M':
                        if TenantPermission."Object Type" = TenantPermission."Object Type"::"Table Data" then
                            if TenantPermission."Modify Permission" <> PermissionOption then begin
                                TenantPermission."Modify Permission" := PermissionOption;
                                ModifyPermissionLine := true;
                                Session.LogAuditMessage(StrSubstNo(PermissionUpdatedLbl, RIMDX, TenantPermission."App ID", TenantPermission."Role ID", TenantPermission."Object Type", TenantPermission."Object ID",
                                    TenantPermission."Modify Permission", UserSecurityId()), SecurityOperationResult::Success, AuditCategory::RoleManagement, 2, 0);
                            end;
                    'D':
                        if TenantPermission."Object Type" = TenantPermission."Object Type"::"Table Data" then
                            if TenantPermission."Delete Permission" <> PermissionOption then begin
                                TenantPermission."Delete Permission" := PermissionOption;
                                ModifyPermissionLine := true;
                                Session.LogAuditMessage(StrSubstNo(PermissionUpdatedLbl, RIMDX, TenantPermission."App ID", TenantPermission."Role ID", TenantPermission."Object Type", TenantPermission."Object ID",
                                    TenantPermission."Delete Permission", UserSecurityId()), SecurityOperationResult::Success, AuditCategory::RoleManagement, 2, 0);
                            end;
                    'X':
                        if TenantPermission."Object Type" <> TenantPermission."Object Type"::"Table Data" then
                            if TenantPermission."Execute Permission" <> PermissionOption then begin
                                TenantPermission."Execute Permission" := PermissionOption;
                                ModifyPermissionLine := true;
                                Session.LogAuditMessage(StrSubstNo(PermissionUpdatedLbl, RIMDX, TenantPermission."App ID", TenantPermission."Role ID", TenantPermission."Object Type", TenantPermission."Object ID",
                                    TenantPermission."Execute Permission", UserSecurityId()), SecurityOperationResult::Success, AuditCategory::RoleManagement, 2, 0);
                            end;
                    '*':
                        if TenantPermission."Object Type" = TenantPermission."Object Type"::"Table Data" then begin
                            if (TenantPermission."Read Permission" <> PermissionOption) or
                                (TenantPermission."Insert Permission" <> PermissionOption) or
                                (TenantPermission."Modify Permission" <> PermissionOption) or
                                (TenantPermission."Delete Permission" <> PermissionOption)
                            then begin
                                TenantPermission."Read Permission" := PermissionOption;
                                TenantPermission."Insert Permission" := PermissionOption;
                                TenantPermission."Modify Permission" := PermissionOption;
                                TenantPermission."Delete Permission" := PermissionOption;
                                ModifyPermissionLine := true;
                                Session.LogAuditMessage(StrSubstNo(MultiplePermissionsUpdatedLbl, TenantPermission."App ID", TenantPermission."Role ID", TenantPermission."Object Type", TenantPermission."Object ID",
                                    TenantPermission."Read Permission", TenantPermission."Insert Permission", TenantPermission."Modify Permission", TenantPermission."Delete Permission", UserSecurityId()), SecurityOperationResult::Success, AuditCategory::RoleManagement, 2, 0);
                            end;
                        end else
                            if TenantPermission."Execute Permission" <> PermissionOption then begin
                                TenantPermission."Execute Permission" := PermissionOption;
                                ModifyPermissionLine := true;
                                Session.LogAuditMessage(StrSubstNo(PermissionUpdatedLbl, RIMDX, TenantPermission."App ID", TenantPermission."Role ID", TenantPermission."Object Type", TenantPermission."Object ID",
                                    TenantPermission."Execute Permission", UserSecurityId()), SecurityOperationResult::Success, AuditCategory::RoleManagement, 2, 0);
                            end;
                end;
                if ModifyPermissionLine then
                    TenantPermission.Modify();
            until TenantPermission.Next() = 0;
    end;

    procedure IsPermissionEmpty(var TenantPermission: Record "Tenant Permission"): Boolean
    begin
        exit(
            (TenantPermission."Execute Permission" = TenantPermission."Execute Permission"::" ") and
           (TenantPermission."Read Permission" = TenantPermission."Read Permission"::" ") and
           (TenantPermission."Insert Permission" = TenantPermission."Insert Permission"::" ") and
           (TenantPermission."Modify Permission" = TenantPermission."Modify Permission"::" ") and
           (TenantPermission."Delete Permission" = TenantPermission."Delete Permission"::" "));
    end;

    procedure VerifyPermissionAlreadyExists(var TenantPermissionRec: Record "Tenant Permission"): Boolean
    var
        TenantPermission: Record "Tenant Permission";
    begin
        if TenantPermission.Get(TenantPermissionRec."App ID", TenantPermissionRec."Role ID", TenantPermissionRec."Object Type", TenantPermissionRec."Object ID") then
            if TenantPermission.Type <> TenantPermissionRec.Type then
                Error(PermissionAlreadyExistsWithDifferentTypeErr, TenantPermission.Type);
    end;

    procedure EmptyIrrelevantPermissionFields(var TenantPermission: Record "Tenant Permission")
    begin
        if TenantPermission."Object Type" = TenantPermission."Object Type"::"Table Data" then
            TenantPermission."Execute Permission" := TenantPermission."Execute Permission"::" "
        else begin
            TenantPermission."Read Permission" := TenantPermission."Read Permission"::" ";
            TenantPermission."Insert Permission" := TenantPermission."Insert Permission"::" ";
            TenantPermission."Modify Permission" := TenantPermission."Modify Permission"::" ";
            TenantPermission."Delete Permission" := TenantPermission."Delete Permission"::" ";
        end;
    end;

    procedure SetDefaultPermissionFields(var TenantPermission: Record "Tenant Permission")
    begin
        if TenantPermission."Object Type" = TenantPermission."Object Type"::"Table Data" then begin
            TenantPermission."Read Permission" := TenantPermission."Read Permission"::Yes;
            TenantPermission."Insert Permission" := TenantPermission."Insert Permission"::" ";
            TenantPermission."Modify Permission" := TenantPermission."Modify Permission"::" ";
            TenantPermission."Delete Permission" := TenantPermission."Delete Permission"::" ";
        end else
            TenantPermission."Execute Permission" := TenantPermission."Execute Permission"::Yes;
    end;

    procedure GetObjectionCaptionAndName(var TenantPermission: Record "Tenant Permission"; var ObjectCaption: Text; var ObjectName: Text)
    var
        AllObj: Record AllObj;
    begin
        if TenantPermission."Object ID" <> 0 then begin
            TenantPermission.CalcFields("Object Name");
            ObjectCaption := TenantPermission."Object Name";
            ObjectName := '';
            if AllObj.Get(TenantPermission."Object Type", TenantPermission."Object ID") then
                ObjectName := AllObj."Object Name";
        end else begin
            ObjectName := CopyStr(StrSubstNo(AllObjTxt, TenantPermission."Object Type"), 1, MaxStrLen(TenantPermission."Object Name"));
            ObjectCaption := ObjectName;
        end;
    end;

    procedure GetObjectCaptionAndName(var MetadataPermission: Record "Metadata Permission"; var ObjectCaption: Text; var ObjectName: Text)
    var
        AllObj: Record AllObj;
    begin
        if MetadataPermission."Object ID" <> 0 then begin
            MetadataPermission.CalcFields("Object Name");
            ObjectCaption := MetadataPermission."Object Name";
            ObjectName := '';
            if AllObj.Get(MetadataPermission."Object Type", MetadataPermission."Object ID") then
                ObjectName := AllObj."Object Name";
        end else begin
            ObjectName := CopyStr(StrSubstNo(AllObjTxt, MetadataPermission."Object Type"), 1, MaxStrLen(MetadataPermission."Object Name"));
            ObjectCaption := ObjectName;
        end;
    end;

    procedure GetObjectCaptionAndName(var ExpandedPermission: Record "Expanded Permission"; var ObjectCaption: Text; var ObjectName: Text)
    var
        AllObj: Record AllObj;
    begin
        if ExpandedPermission."Object ID" <> 0 then begin
            ExpandedPermission.CalcFields("Object Name");
            ObjectCaption := ExpandedPermission."Object Name";
            ObjectName := '';
            if AllObj.Get(ExpandedPermission."Object Type", ExpandedPermission."Object ID") then
                ObjectName := AllObj."Object Name";
        end else begin
            ObjectName := CopyStr(StrSubstNo(AllObjExceptTxt, ExpandedPermission."Object Type"), 1, MaxStrLen(ExpandedPermission."Object Name"));
            ObjectCaption := ObjectName;
        end;
    end;

    procedure GetObjectName(var ExpandedPermission: Record "Expanded Permission"; var ObjectName: Text)
    begin
        if ExpandedPermission."Object ID" <> 0 then begin
            ExpandedPermission.CalcFields("Object Name");
            ObjectName := ExpandedPermission."Object Name";
        end else
            ObjectName := CopyStr(StrSubstNo(AllObjExceptTxt, ExpandedPermission."Object Type"), 1, MaxStrLen(ExpandedPermission."Object Name"));
    end;

    procedure GetPermission(PermissionType: Option Include,Exclude; PermissionAsTxt: Text): Option " ",Yes,Indirect
    begin
        case PermissionAsTxt of
            Format(IncludeOption::Yes), Format(ExcludeOption::Exclude):
                exit(IncludeOption::Yes);
            Format(IncludeOption::Indirect), Format(ExcludeOption::"Reduce to indirect"):
                exit(IncludeOption::Indirect);
            else
                exit(IncludeOption::" ")
        end;
    end;

    procedure GetPermissionAsTxt(IncludeExcludeOption: Option Include,Exclude; PermissionOption: Option " ",Yes,Indirect) Result: Text[50]
    begin
        if IncludeExcludeOption = IncludeExcludeOption::Exclude then
            case PermissionOption of
                PermissionOption::" ":
                    exit(Format(ExcludeOption::" "));
                PermissionOption::Yes:
                    exit(Format(ExcludeOption::Exclude));
                PermissionOption::Indirect:
                    exit(Format(ExcludeOption::"Reduce to indirect"));
            end
        else
            exit(Format(PermissionOption));
    end;

    procedure FillLookupBuffer(var PermissionLookupBuffer: Record "Permission Lookup Buffer" temporary)
    begin
        if PermissionLookupBuffer.GetFilter("Lookup Type") = '' then
            exit;

        PermissionLookupBuffer.DeleteAll();

        AddOption(1, Format(IncludeOption::" "), Format(IncludeDescriptionOption::"Specifies no permission"), PermissionLookupBuffer."Lookup Type"::Include, PermissionLookupBuffer);
        AddOption(1, Format(ExcludeOption::" "), Format(ExcludeDescriptionOption::"No change to permission"), PermissionLookupBuffer."Lookup Type"::Exclude, PermissionLookupBuffer);
        AddOption(2, Format(IncludeOption::Yes), Format(IncludeDescriptionOption::"Specifies direct permission"), PermissionLookupBuffer."Lookup Type"::Include, PermissionLookupBuffer);
        AddOption(2, Format(ExcludeOption::Exclude), Format(ExcludeDescriptionOption::"Excludes any permission"), PermissionLookupBuffer."Lookup Type"::Exclude, PermissionLookupBuffer);
        AddOption(3, Format(IncludeOption::Indirect), Format(IncludeDescriptionOption::"Specifies indirect permission"), PermissionLookupBuffer."Lookup Type"::Include, PermissionLookupBuffer);
        AddOption(3, Format(ExcludeOption::"Reduce to indirect"), Format(ExcludeDescriptionOption::"Excludes any direct permission"), PermissionLookupBuffer."Lookup Type"::Exclude, PermissionLookupBuffer);
    end;

    local procedure AddOption(RecId: Integer; Caption: Text[50]; Description: Text[100]; LookupType: Option Include,Exclude; var PermissionLookupBuffer: Record "Permission Lookup Buffer" temporary)
    begin
        PermissionLookupBuffer.Init();
        PermissionLookupBuffer.ID := RecId;
        PermissionLookupBuffer."Option Caption" := Caption;
        PermissionLookupBuffer."Option Description" := CopyStr(Description, 1, MaxStrLen(PermissionLookupBuffer."Option Description"));
        PermissionLookupBuffer."Lookup Type" := LookupType;
        PermissionLookupBuffer.Insert();
    end;

    local procedure AddNewPermission(AppId: Guid; RoleId: Code[20]; PermissionObjectType: Option; ObjectID: Integer)
    var
        TenantPermission: Record "Tenant Permission";
    begin
        TenantPermission."App ID" := AppId;
        TenantPermission."Role ID" := RoleId;
        TenantPermission."Object Type" := PermissionObjectType;
        TenantPermission."Object ID" := ObjectID;

        VerifyPermissionAlreadyExists(TenantPermission);
        EmptyIrrelevantPermissionFields(TenantPermission);
        SetDefaultPermissionFields(TenantPermission);

        TenantPermission.Insert();
    end;

    local procedure SetupObjectsPage(PageCaption: Text; var Objects: Page Objects; var TempAllObjWithCaption: Record AllObjWithCaption temporary)
    begin
        Objects.SetTableView(TempAllObjWithCaption);
        Objects.SetObjectTypeVisible(true);
        Objects.SetObjectNameVisible(true);
        Objects.SetObjectCaptionVisible(false);
        Objects.Caption(PageCaption);
        Objects.LookupMode(true);
    end;
}