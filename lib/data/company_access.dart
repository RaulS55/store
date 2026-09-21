import '../models/app_user.dart';
import '../models/company.dart';
import '../models/company_role.dart';
import '../models/invitation.dart';
import '../models/membership.dart';

abstract class CompanyAccess {
  Future<AppUser?> getUser(String uid);

  Future<Company?> getCompany(String companyId);

  Future<Company?> findCompanyByOwner(String uid);

  Future<Membership?> getMembership(String companyId, String uid);

  Future<List<Membership>> listMembers(String companyId);

  Future<List<Invitation>> listInvitations(String companyId);

  Future<Invitation?> getInvitation(String companyId, String invitationId);

  Future<Invitation?> findPendingInvitationByEmail(String email);

  Future<Invitation?> findPendingInvitationByCode(String email, String code);

  Future<void> createOwnerCompany({
    required String uid,
    required String email,
    required String displayName,
    required String companyName,
  });

  Future<void> ensureOwnerProfile({
    required String uid,
    required String email,
    required String displayName,
    required Company company,
  });

  Future<Invitation> createInvitation({
    required String companyId,
    required String companyName,
    required String email,
    required String invitedBy,
    required CompanyRole role,
  });

  Future<void> acceptInvitation({
    required String uid,
    required String email,
    required String displayName,
    required String companyId,
    required String invitationId,
  });

  Future<void> revokeInvitation({
    required String companyId,
    required String invitationId,
  });

  Future<void> removeMember({required String companyId, required String uid});

  Future<void> clearOrphanCompany(String uid);

  Future<void> updateCompanyRubro(String companyId, CompanyRubro rubro);

  Future<void> updateCompanyPhone(String companyId, String? phone);

  Future<void> updateCompanyName(String companyId, String name);

  Future<void> updateCompanyLogo(String companyId, String? logoUrl);

  Future<void> updateCompanySocials(
    String companyId, {
    String? instagram,
    String? tiktok,
    String? facebook,
  });
}
