import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../business-layer/services/connectivity_service.dart';
import '../landing_page/app_theme.dart';

/// Compact connectivity status indicator for app bars
class ConnectivityIndicator extends StatelessWidget {
  const ConnectivityIndicator({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<ConnectionStatus>(
      stream: ConnectivityService().statusStream,
      initialData: ConnectivityService().currentStatus,
      builder: (context, snapshot) {
        final status = snapshot.data ?? ConnectivityService().currentStatus;
        
        print('[ConnectivityIndicator] Building - showIndicator: ${status.showIndicator}, isOnline: ${status.isOnline}, isSyncing: ${status.isSyncing}');
        
        if (!status.showIndicator) {
          return const SizedBox.shrink();
        }

        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: status.isSyncing
                ? AppColors.tertiary.withOpacity(0.15)
                : AppColors.error.withOpacity(0.15),
            borderRadius: BorderRadius.circular(999),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (status.isSyncing)
                SizedBox(
                  width: 12,
                  height: 12,
                  child: CircularProgressIndicator(
                    strokeWidth: 1.5,
                    strokeCap: StrokeCap.round,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      AppColors.tertiary,
                    ),
                  ),
                )
              else
                Icon(
                  Icons.cloud_off_rounded,
                  size: 12,
                  color: AppColors.error,
                ),
              const SizedBox(width: 6),
              Text(
                status.displayText,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: status.isSyncing ? AppColors.tertiary : AppColors.error,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
