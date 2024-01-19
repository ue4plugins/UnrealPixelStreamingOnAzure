import {
  DefaultButton,
  Depths,
  DetailsList,
  Dialog,
  DialogFooter,
  DialogType,
  FontSizes,
  IColumn,
  Label,
  MarqueeSelection,
  MessageBar,
  MessageBarType,
  Panel,
  PanelType,
  PrimaryButton,
  Selection,
  SelectionMode,
  Stack,
  TextField,
} from "@fluentui/react";
import React, { useEffect, useState } from "react";
import {
  addAccount,
  Config,
  deleteAccount,
  getAccounts,
  getConfig,
} from "src/api";
import { validatePassword } from "src/util";

export interface Account {
  username: string;
  password?: string;
}

const columns: IColumn[] = [
  {
    key: "username",
    name: "Username",
    ariaLabel: "Username",
    fieldName: "username",
    minWidth: 200,
  },
];

const Accounts = () => {
  const [config, setConfig] = useState<Config>({});
  const [accounts, setAccounts] = useState<Account[]>([]);
  const [newAccount, setNewAccount] = useState<Account>({
    username: "",
    password: "",
  });
  const [newAccountUsernameError, setNewAccountUsernameError] =
    useState<string>();
  const [newAccountPasswordError, setNewAccountPasswordError] =
    useState<string>();
  const [addAccountError, setAddAccountError] = useState<string>();
  const [accountToDelete, setAccountToDelete] = useState<Account | null>(null);
  const [newAccountFormOpen, setNewAccountFormOpen] = useState(false);
  const [deleteDialogOpen, setDeleteDialogOpen] = useState(false);
  const [selection] = useState(new Selection());

  const handleAddClick = () => {
    setNewAccount({ username: "", password: "" });
    setNewAccountFormOpen(true);
  };

  const handleFormDismiss = () => {
    setNewAccountFormOpen(false);
  };

  const handleUpdateUsername = (ev?: any, value?: string) => {
    if (value === undefined || value === null) {
      return;
    }

    if (
      accounts.find(
        (acct) => acct.username.toLowerCase() === value.toLowerCase()
      )
    ) {
      setNewAccountUsernameError(`Username '${value}' already exists`);
    } else {
      setNewAccountUsernameError(undefined);
    }

    const updatedAccount = { ...newAccount, username: value };
    setNewAccount(updatedAccount);
  };

  const handleUpdatePassword = (ev?: any, value?: string) => {
    if (value === undefined || value === null) {
      return;
    }

    setNewAccountPasswordError(validatePassword(value));

    const updatedAccount = { ...newAccount, password: value };
    setNewAccount(updatedAccount);
  };

  const handleAddAccount = async () => {
    try {
      if (
        newAccount.username.trim() === "" ||
        newAccount.password?.trim() === ""
      ) {
        return;
      }

      await addAccount(newAccount);

      const response = await getAccounts();
      setAccounts(response);

      handleFormDismiss();
    } catch (err) {
      setAddAccountError(
        "There was a problem adding your account. Please try again."
      );

      const response = await getAccounts();
      setAccounts(response);

      console.log(err);
    }
  };

  const handlePrepDeleteAccount = async () => {
    if (selection.getSelectedCount() < 1) {
      return;
    }

    const selectedIdx = selection.getSelectedIndices()[0];
    setAccountToDelete(accounts[selectedIdx]);
    setDeleteDialogOpen(true);
  };

  const handleDeleteAccount = async () => {
    if (accountToDelete) {
      await deleteAccount(accountToDelete);

      const response = await getAccounts();
      setAccounts(response);
    }

    setAccountToDelete(null);
    setDeleteDialogOpen(false);
  };

  const handleOuterClick = (ev?: React.MouseEvent) => {
    ev?.preventDefault();
  };

  useEffect(() => {
    getConfig().then((response) => setConfig(response || {}));
    getAccounts().then((response) => setAccounts(response || []));
  }, []);

  if (!config.enableAuthentication) {
    return <div>Authentication is not enabled.</div>;
  }

  return (
    <div>
      <div
        style={{
          display: "flex",
          justifyContent: "space-between",
          alignItems: "center",
          color: "#3b3a39",
          fontSize: FontSizes.size42,
        }}
      >
        Accounts
        <div>
          <PrimaryButton text="Add Account" onClick={handleAddClick} />{" "}
          <PrimaryButton
            text="Delete Selected Account"
            onClick={handlePrepDeleteAccount}
          />
        </div>
      </div>
      <div
        style={{
          marginTop: 40,
          boxShadow: Depths.depth4,
          borderRadius: 2,
          minHeight: 200,
          padding: 10,
          background: "white",
        }}
      >
        <MarqueeSelection selection={selection}>
          <DetailsList
            selectionMode={SelectionMode.single}
            columns={columns}
            items={accounts}
            selection={selection}
          />
        </MarqueeSelection>
      </div>
      <Panel
        headerText="Add Account"
        isBlocking={true}
        isLightDismiss={false}
        isOpen={newAccountFormOpen}
        type={PanelType.medium}
        onDismiss={handleFormDismiss}
        onOuterClick={handleOuterClick}
      >
        <Stack tokens={{ childrenGap: 8, padding: "20px 0" }}>
          {addAccountError && (
            <Stack.Item>
              <MessageBar
                messageBarType={MessageBarType.error}
                isMultiline={false}
                onDismiss={() => setAddAccountError(undefined)}
                dismissButtonAriaLabel="Close"
              >
                {addAccountError}
              </MessageBar>
            </Stack.Item>
          )}
          <Stack.Item>
            <Label>Username</Label>
            <TextField
              value={newAccount.username}
              errorMessage={newAccountUsernameError}
              onChange={handleUpdateUsername}
            />
          </Stack.Item>
          <Stack.Item>
            <Label>Password</Label>
            <TextField
              type="password"
              value={newAccount.password}
              errorMessage={newAccountPasswordError}
              onChange={handleUpdatePassword}
            />
          </Stack.Item>
          <Stack.Item style={{ marginTop: 100 }}>
            <PrimaryButton
              disabled={
                !newAccount.username ||
                !newAccount.password ||
                !!newAccountPasswordError ||
                !!newAccountUsernameError
              }
              text="Add Account"
              onClick={handleAddAccount}
            />
            <DefaultButton
              text="Cancel"
              onClick={handleFormDismiss}
              style={{ marginLeft: 8 }}
            />
          </Stack.Item>
        </Stack>
      </Panel>
      <Dialog
        hidden={!deleteDialogOpen}
        onDismiss={() => setDeleteDialogOpen(false)}
        dialogContentProps={{
          type: DialogType.normal,
          title: "Are you sure?",
          subText: `Are you sure you want to delete the account for ${accountToDelete?.username}?`,
        }}
      >
        <DialogFooter>
          <PrimaryButton onClick={handleDeleteAccount} text="Yes" />
          <DefaultButton onClick={() => setDeleteDialogOpen(false)} text="No" />
        </DialogFooter>
      </Dialog>
    </div>
  );
};

export default Accounts;
